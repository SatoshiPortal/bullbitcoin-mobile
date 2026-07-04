import 'dart:async';

import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/activate_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_wallet_owned_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_cubit.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_state.dart';
import 'package:test/test.dart';

void main() {
  group('LightningAddressActivationCubit', () {
    late _FakeActivateWalletOwnedLightningAddressUsecase activate;
    late _FakeLookupWalletOwnedLightningAddressRegistrationUsecase lookup;
    late LightningAddressActivationCubit cubit;

    setUp(() {
      activate = _FakeActivateWalletOwnedLightningAddressUsecase();
      lookup = _FakeLookupWalletOwnedLightningAddressRegistrationUsecase();
      cubit = LightningAddressActivationCubit(activate, lookup);
    });

    tearDown(() => cubit.close());

    test('load active status without a copyable address', () async {
      lookup.result = const LightningAddressStatus(nym: 'alice', active: true);

      await cubit.load();

      expect(lookup.executeCalls, 1);
      expect(cubit.state.status, LightningAddressActivationStatus.active);
      expect(cubit.state.nym, 'alice');
      expect(cubit.state.registeredAddress, isNull);
    });

    test('a failed lookup still lets a first-time user register', () async {
      // I10: registration is independent of the status lookup, so after a
      // lookup failure the user must be able to start registration (the
      // failure view is no longer retry-only) - showing the form moves to an
      // idle, form-ready state with the failure cleared.
      lookup.error = Exception('lookup offline');

      await cubit.load();
      expect(cubit.state.status, LightningAddressActivationStatus.failure);
      expect(
        cubit.state.failure,
        LightningAddressActivationFailure.lookupFailed,
      );

      cubit.showRegistrationForm();

      expect(cubit.state.status, LightningAddressActivationStatus.idle);
      expect(cubit.state.failure, isNull);
    });

    test(
      'load inactive known status keeps it distinct from first run',
      () async {
        lookup.result = const LightningAddressStatus(
          nym: 'alice',
          active: false,
        );

        await cubit.load();

        expect(cubit.state.status, LightningAddressActivationStatus.inactive);
        expect(cubit.state.nym, 'alice');
        expect(cubit.state.registeredAddress, isNull);
      },
    );

    test('blank nym fails before registration', () async {
      cubit.nymChanged('   ');

      await cubit.submit();

      expect(activate.nyms, isEmpty);
      expect(cubit.state.status, LightningAddressActivationStatus.failure);
      expect(cubit.state.failure, LightningAddressActivationFailure.invalidNym);
    });

    test('full address nym fails before registration', () async {
      cubit.nymChanged('alice@example.invalid');

      await cubit.submit();

      expect(activate.nyms, isEmpty);
      expect(cubit.state.status, LightningAddressActivationStatus.failure);
      expect(cubit.state.failure, LightningAddressActivationFailure.invalidNym);
    });

    test('successful registration stores server-returned address', () async {
      cubit.nymChanged('alice');

      await cubit.submit();

      expect(activate.nyms.single, 'alice');
      expect(cubit.state.status, LightningAddressActivationStatus.registered);
      expect(cubit.state.nym, 'alice');
      expect(cubit.state.registeredAddress, 'alice@example.invalid');
    });

    test('missing default wallet maps to actionable setup failure', () async {
      cubit.nymChanged('alice');
      activate.error =
          WalletOwnedLightningAddressActivationException.fromRegistration(
            WalletOwnedLightningAddressRegistrationException.localPreparation(
              cause: LightningAddressException.localPreparationFailed(
                code: 'NoDefaultBitcoinWallet',
                retryable: false,
              ),
            ),
          );

      await cubit.submit();

      expect(cubit.state.status, LightningAddressActivationStatus.failure);
      expect(
        cubit.state.failure,
        LightningAddressActivationFailure.noDefaultBitcoinWallet,
      );
      expect(cubit.state.registeredAddress, isNull);
    });

    test('uncertain submission maps to check-status state', () async {
      cubit.nymChanged('alice');
      activate
          .error = WalletOwnedLightningAddressActivationException.fromRegistration(
        WalletOwnedLightningAddressRegistrationException.registrationSubmission(
          cause: const LightningAddressTimeoutException(
            code: 'Timeout',
            retryable: true,
          ),
          walletId: 'wallet-id',
          walletCreated: true,
        ),
      );

      await cubit.submit();

      expect(cubit.state.status, LightningAddressActivationStatus.failure);
      expect(
        cubit.state.failure,
        LightningAddressActivationFailure.submissionUncertain,
      );
      expect(cubit.state.registeredAddress, isNull);
    });

    test('server rejection maps to rejected failure', () async {
      cubit.nymChanged('alice');
      activate
          .error = WalletOwnedLightningAddressActivationException.fromRegistration(
        WalletOwnedLightningAddressRegistrationException.registrationSubmission(
          cause: const LightningAddressServerRejectedRequestException(
            code: 'Rejected',
            retryable: false,
          ),
          walletId: 'wallet-id',
          walletCreated: true,
        ),
      );

      await cubit.submit();

      expect(cubit.state.status, LightningAddressActivationStatus.failure);
      expect(cubit.state.failure, LightningAddressActivationFailure.rejected);
    });

    test('load failure keeps status distinct from inactive', () async {
      lookup.error = const LightningAddressNetworkException(
        code: 'Network',
        retryable: true,
      );

      await cubit.load();

      expect(cubit.state.status, LightningAddressActivationStatus.failure);
      expect(
        cubit.state.failure,
        LightningAddressActivationFailure.lookupFailed,
      );
      expect(cubit.state.registeredAddress, isNull);
    });

    test('missing default wallet lookup maps to actionable failure', () async {
      lookup.error = LightningAddressException.localPreparationFailed(
        code: 'NoDefaultBitcoinWallet',
        retryable: false,
      );

      await cubit.load();

      expect(cubit.state.status, LightningAddressActivationStatus.failure);
      expect(
        cubit.state.failure,
        LightningAddressActivationFailure.noDefaultBitcoinWallet,
      );
      expect(cubit.state.registeredAddress, isNull);
    });

    test('failed status check preserves uncertain submission state', () async {
      cubit.nymChanged('alice');
      activate
          .error = WalletOwnedLightningAddressActivationException.fromRegistration(
        WalletOwnedLightningAddressRegistrationException.registrationSubmission(
          cause: const LightningAddressTimeoutException(
            code: 'Timeout',
            retryable: true,
          ),
          walletId: 'wallet-id',
          walletCreated: true,
        ),
      );
      await cubit.submit();
      lookup.error = const LightningAddressNetworkException(
        code: 'Network',
        retryable: true,
      );

      await cubit.load();

      expect(cubit.state.status, LightningAddressActivationStatus.failure);
      expect(
        cubit.state.failure,
        LightningAddressActivationFailure.submissionUncertain,
      );
    });

    test('stale lookup result does not overwrite active submission', () async {
      final pendingLookup = Completer<LightningAddressStatus>();
      lookup.pendingResult = pendingLookup.future;

      final loadFuture = cubit.load();
      cubit.nymChanged('alice');
      final submitFuture = cubit.submit();
      pendingLookup.complete(
        const LightningAddressStatus(nym: 'old', active: false),
      );
      await loadFuture;
      await submitFuture;

      expect(cubit.state.status, LightningAddressActivationStatus.registered);
      expect(cubit.state.nym, 'alice');
      expect(cubit.state.registeredAddress, 'alice@example.invalid');
    });
  });
}

class _FakeActivateWalletOwnedLightningAddressUsecase
    implements ActivateWalletOwnedLightningAddressUsecase {
  final nyms = <String>[];
  Object? error;

  @override
  Future<LightningAddressRegistration> execute({required String nym}) async {
    nyms.add(nym);
    final error = this.error;
    if (error != null) throw error;
    return LightningAddressRegistration(
      nym: nym,
      lightningAddress: '$nym@example.invalid',
    );
  }
}

class _FakeLookupWalletOwnedLightningAddressRegistrationUsecase
    implements LookupWalletOwnedLightningAddressRegistrationUsecase {
  int executeCalls = 0;
  LightningAddressStatus result = const LightningAddressStatus(
    nym: '',
    active: false,
  );
  Future<LightningAddressStatus>? pendingResult;
  Object? error;

  @override
  Future<LightningAddressStatus> execute() async {
    executeCalls += 1;
    final error = this.error;
    if (error != null) throw error;
    final pendingResult = this.pendingResult;
    if (pendingResult != null) return pendingResult;
    return result;
  }
}
