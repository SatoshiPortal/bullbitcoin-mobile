import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/get_lightning_address_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_receive_readiness_usecase.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_cubit.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _quota = LightningAddressPermanentNameQuota(
  used: 1,
  cap: 3,
  remaining: 2,
);

void main() {
  test(
    'fails closed when the permanent-name capability is unavailable',
    () async {
      final cubit = _cubit(capability: const Err(_networkFailure));

      await cubit.load();

      expect(cubit.state.status, LightningAddressActivationStatus.failure);
      expect(
        cubit.state.failure,
        LightningAddressActivationFailure.capabilityUnavailable,
      );
      expect(cubit.state.permanentNamesSupported, isFalse);
    },
  );

  test('keeps a legacy active address usable but not manageable', () async {
    final cubit = _cubit(
      capability: const Ok(false),
      readiness: Ok(_readiness(active: true, permanent: false)),
    );

    await cubit.load();

    expect(cubit.state.status, LightningAddressActivationStatus.active);
    expect(cubit.state.registeredAddress, 'alice@example.com');
    expect(cubit.state.hasPermanentNym, isFalse);
  });

  test('hides an inactive legacy registration', () async {
    final cubit = _cubit(
      capability: const Ok(false),
      readiness: Ok(_readiness(active: false, permanent: false)),
    );

    await cubit.load();

    expect(cubit.state.status, LightningAddressActivationStatus.unsupported);
    expect(cubit.state.nym, 'alice');
  });

  test(
    'offers first claim only after an authoritative not-found result',
    () async {
      final cubit = _cubit(
        readiness: const Err(
          LightningAddressFailure.operation(
            kind: LightningAddressFailureKind.serverRejected,
            code: 'NymNotFound',
            retryable: false,
          ),
        ),
      );

      await cubit.load();

      expect(cubit.state.status, LightningAddressActivationStatus.idle);
      expect(cubit.state.hasPermanentNym, isFalse);
    },
  );

  test(
    'distinguishes active, inactive, incomplete and local-setup states',
    () async {
      final cases =
          <
            (LightningAddressReceiveReadiness, LightningAddressActivationStatus)
          >[
            (_readiness(active: true), LightningAddressActivationStatus.active),
            (
              _readiness(active: false),
              LightningAddressActivationStatus.inactive,
            ),
            (
              _readiness(active: true, address: null),
              LightningAddressActivationStatus.addressUnavailable,
            ),
            (
              _readiness(active: true, localSetupFailed: true),
              LightningAddressActivationStatus.activeLocalSetupFailed,
            ),
          ];

      for (final (readiness, expected) in cases) {
        final cubit = _cubit(readiness: Ok(readiness));
        await cubit.load();
        expect(cubit.state.status, expected);
        await cubit.close();
      }
    },
  );

  test(
    'normalizes and rejects invalid or reserved claims without writing',
    () async {
      var activations = 0;
      final cubit = _cubit(
        activate: (_) async {
          activations++;
          return const Ok(
            LightningAddressRegistration(
              nym: 'alice',
              lightningAddress: 'alice@example.com',
            ),
          );
        },
      );
      await cubit.load();

      cubit.nymChanged(' ADMIN ');
      await cubit.submit();
      expect(
        cubit.state.failure,
        LightningAddressActivationFailure.reservedNym,
      );
      cubit.nymChanged('not valid');
      await cubit.submit();
      expect(cubit.state.failure, LightningAddressActivationFailure.invalidNym);
      expect(activations, 0);
    },
  );

  test('re-reads status after a successful claim', () async {
    var activations = 0;
    final cubit = _cubit(
      readinessSequence: [
        const Err(
          LightningAddressFailure.operation(
            kind: LightningAddressFailureKind.serverRejected,
            code: 'NymNotFound',
            retryable: false,
          ),
        ),
        Ok(_readiness(active: true)),
      ],
      activate: (nym) async {
        activations++;
        return Ok(
          LightningAddressRegistration(
            nym: nym,
            lightningAddress: '$nym@example.com',
          ),
        );
      },
    );
    await cubit.load();
    cubit.nymChanged('Alice');
    await cubit.submit();

    expect(activations, 1);
    expect(cubit.state.status, LightningAddressActivationStatus.active);
    expect(cubit.state.nym, 'alice');
    expect(cubit.state.hasPermanentNym, isTrue);
  });

  test('maps an unanswered claim to the retryable no-response state', () async {
    final cubit = _cubit(
      activate: (_) async => Err(
        _networkFailure.atPhase(
          LightningAddressFailurePhase.registrationSubmission,
        ),
      ),
    );
    await cubit.load();
    cubit.nymChanged('alice');
    await cubit.submit();

    expect(cubit.state.status, LightningAddressActivationStatus.failure);
    expect(
      cubit.state.failure,
      LightningAddressActivationFailure.noServerResponse,
    );
  });

  test('reconciles an ownership conflict using the server-owned nym', () async {
    final cubit = _cubit(
      readinessSequence: [
        const Err(
          LightningAddressFailure.operation(
            kind: LightningAddressFailureKind.serverRejected,
            code: 'NymNotFound',
            retryable: false,
          ),
        ),
        Ok(_readiness(active: true, nym: 'owned')),
      ],
      activate: (_) async => Err(
        const LightningAddressFailure.operation(
          kind: LightningAddressFailureKind.serverRejected,
          code: 'NymAlreadyAssigned',
          retryable: false,
          ownedNym: 'owned',
        ).atPhase(LightningAddressFailurePhase.registrationSubmission),
      ),
    );
    await cubit.load();
    cubit.nymChanged('alice');
    await cubit.submit();

    expect(cubit.state.nym, 'owned');
    expect(cubit.state.hasPermanentNym, isTrue);
    expect(
      cubit.state.failure,
      LightningAddressActivationFailure.alreadyAssigned,
    );
  });

  test('an uncertain toggle preserves the prior online state', () async {
    final cubit = _cubit(
      readiness: Ok(_readiness(active: true)),
      deactivate: (_) async => const Err(_timeoutFailure),
    );
    await cubit.load();
    await cubit.deactivate();

    expect(cubit.state.status, LightningAddressActivationStatus.active);
    expect(
      cubit.state.failure,
      LightningAddressActivationFailure.toggleUncertain,
    );
  });
}

const _networkFailure = LightningAddressFailure.operation(
  kind: LightningAddressFailureKind.network,
  code: 'Network',
  retryable: true,
);
const _timeoutFailure = LightningAddressFailure.operation(
  kind: LightningAddressFailureKind.timeout,
  code: 'Timeout',
  retryable: true,
);

LightningAddressActivationCubit _cubit({
  Result<bool, LightningAddressFailure> capability = const Ok(true),
  Result<LightningAddressReceiveReadiness, LightningAddressFailure>? readiness,
  List<Result<LightningAddressReceiveReadiness, LightningAddressFailure>>?
  readinessSequence,
  Future<Result<LightningAddressRegistration, LightningAddressFailure>>
  Function(String nym)?
  activate,
  Future<Result<void, LightningAddressFailure>> Function(String nym)?
  deactivate,
}) {
  final readinessResult =
      readiness ??
      const Err(
        LightningAddressFailure.operation(
          kind: LightningAddressFailureKind.serverRejected,
          code: 'NymNotFound',
          retryable: false,
        ),
      );
  return LightningAddressActivationCubit(
    getCapability: () async => capability,
    activate: ({required nym}) =>
        activate?.call(nym) ??
        Future.value(
          Ok(
            LightningAddressRegistration(
              nym: nym,
              lightningAddress: '$nym@example.com',
            ),
          ),
        ),
    deactivate: ({required nym}) =>
        deactivate?.call(nym) ?? Future.value(const Ok(null)),
    lookupReadiness: () async =>
        readinessSequence?.removeAt(0) ?? readinessResult,
    getWalletBehavior: () async => const LightningAddressWalletBehaviorAbsent(),
    updateWalletBehavior:
        ({required walletId, hideOnHome, autoSweepEnabled}) async => true,
  );
}

LightningAddressReceiveReadiness _readiness({
  required bool active,
  bool permanent = true,
  String nym = 'alice',
  String? address = 'alice@example.com',
  bool localSetupFailed = false,
}) {
  return LightningAddressReceiveReadiness(
    registration: LightningAddressStatus(
      nym: nym,
      active: active,
      lightningAddress: address,
      permanentNameStatus: permanent
          ? LightningAddressPermanentNameStatus(
              nym: nym,
              lightningAddressOnline: active,
              quota: _quota,
            )
          : null,
    ),
    localSetupFailed: localSetupFailed,
    localSetupRetryable: localSetupFailed,
    autoSweepEnabled: !localSetupFailed,
  );
}
