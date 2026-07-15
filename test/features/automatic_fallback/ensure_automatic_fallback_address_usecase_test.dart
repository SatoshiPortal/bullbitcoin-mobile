import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_failure.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_service_port.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_setup.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_wallet_port.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/ensure_automatic_fallback_address_usecase.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:flutter_test/flutter_test.dart';

const _address = 'bc1qfallbackaddress';
const _otherAddress = 'bc1qotherfallbackaddress';

final _context = AutomaticFallbackWalletContext(
  walletId: 'default-bitcoin',
  signer: BullnymAuthSigner(
    npubHex: 'fixture-npub',
    signHashHex: (_) => 'fixture-signature',
  ),
);

BullnymRecoveryAddressLookupResult _registered(
  String address, {
  int commitmentVersion = 1,
  int signedAtUnix = 1_700_000_000,
}) {
  return BullnymRecoveryAddressLookupResult(
    version: bullnymRecoveryAddressContractVersion,
    isRegistered: true,
    btcAddress: address,
    commitmentVersion: commitmentVersion,
    signedAtUnix: signedAtUnix,
  );
}

BullnymRecoveryAddressRegistrationResult _ack() {
  return const BullnymRecoveryAddressRegistrationResult(
    version: bullnymRecoveryAddressContractVersion,
    isRegistered: true,
    signedAtUnix: 1_700_000_000,
  );
}

class _FakeWalletPort implements AutomaticFallbackWalletPort {
  final List<String> events;
  Result<AutomaticFallbackWalletContext, AutomaticFallbackFailure>
  contextResult = Ok(_context);
  Result<String?, AutomaticFallbackFailure> pendingResult = const Ok(null);
  Result<String, AutomaticFallbackFailure> freshResult = const Ok(_address);
  Result<bool, AutomaticFallbackFailure> ownershipResult = const Ok(true);
  Result<void, AutomaticFallbackFailure> labelResult = const Ok(null);
  int pendingCalls = 0;
  int freshCalls = 0;
  int ownershipCalls = 0;
  int labelCalls = 0;

  _FakeWalletPort(this.events);

  @override
  Future<Result<AutomaticFallbackWalletContext, AutomaticFallbackFailure>>
  loadCurrentDefaultBitcoinWallet() async {
    events.add('wallet');
    return contextResult;
  }

  @override
  Future<Result<String?, AutomaticFallbackFailure>> findPendingAddress(
    AutomaticFallbackWalletContext context,
  ) async {
    pendingCalls++;
    events.add('pending');
    return pendingResult;
  }

  @override
  Future<Result<String, AutomaticFallbackFailure>> generateFreshAddress(
    AutomaticFallbackWalletContext context,
  ) async {
    freshCalls++;
    events.add('fresh');
    return freshResult;
  }

  @override
  Future<Result<bool, AutomaticFallbackFailure>> ownsAddress(
    AutomaticFallbackWalletContext context,
    String btcAddress,
  ) async {
    ownershipCalls++;
    events.add('owns:$btcAddress');
    return ownershipResult;
  }

  @override
  Future<Result<void, AutomaticFallbackFailure>> ensureLabel(
    AutomaticFallbackWalletContext context,
    String btcAddress,
  ) async {
    labelCalls++;
    events.add('label:$btcAddress');
    return labelResult;
  }
}

class _FakeServicePort implements AutomaticFallbackServicePort {
  final List<String> events;
  final List<
    Result<BullnymRecoveryAddressLookupResult, AutomaticFallbackFailure>
  >
  lookupResults;
  Result<BullnymRecoveryAddressRegistrationResult, AutomaticFallbackFailure>
  registerResult = Ok(_ack());
  int lookupCalls = 0;
  int registerCalls = 0;

  _FakeServicePort(this.events, this.lookupResults);

  @override
  Future<Result<BullnymRecoveryAddressLookupResult, AutomaticFallbackFailure>>
  lookup({required BullnymAuthSigner signer}) async {
    events.add('lookup');
    return lookupResults[lookupCalls++];
  }

  @override
  Future<
    Result<BullnymRecoveryAddressRegistrationResult, AutomaticFallbackFailure>
  >
  register({
    required BullnymAuthSigner signer,
    required String btcAddress,
  }) async {
    registerCalls++;
    events.add('register:$btcAddress');
    return registerResult;
  }
}

AutomaticFallbackFailure _failure(
  Result<AutomaticFallbackSetup, AutomaticFallbackFailure> result,
) {
  expect(result, isA<Err<AutomaticFallbackSetup, AutomaticFallbackFailure>>());
  return (result as Err<AutomaticFallbackSetup, AutomaticFallbackFailure>)
      .failure;
}

void main() {
  test('restored commitment is ownership-checked and relabeled', () async {
    final events = <String>[];
    final wallet = _FakeWalletPort(events);
    final service = _FakeServicePort(events, [Ok(_registered(_address))]);
    final usecase = EnsureAutomaticFallbackAddressUsecase(
      wallet: wallet,
      service: service,
    );

    final result = await usecase.execute();

    final setup =
        (result as Ok<AutomaticFallbackSetup, AutomaticFallbackFailure>).value;
    expect(setup.btcAddress, _address);
    expect(setup.commitmentVersion, 1);
    expect(setup.signedAtUnix, 1_700_000_000);
    expect(setup.registeredNow, isFalse);
    expect(wallet.pendingCalls, 0);
    expect(wallet.freshCalls, 0);
    expect(wallet.ownershipCalls, 1);
    expect(wallet.labelCalls, 1);
    expect(service.registerCalls, 0);
    expect(events, ['wallet', 'lookup', 'owns:$_address', 'label:$_address']);
  });

  test(
    'pending candidate is reused, labeled, registered, and read back',
    () async {
      final events = <String>[];
      final wallet = _FakeWalletPort(events)
        ..pendingResult = const Ok(_address);
      final service = _FakeServicePort(events, [
        const Ok(BullnymRecoveryAddressLookupResult.unregistered()),
        Ok(_registered(_address)),
      ]);
      final usecase = EnsureAutomaticFallbackAddressUsecase(
        wallet: wallet,
        service: service,
      );

      final result = await usecase.execute();

      final setup =
          (result as Ok<AutomaticFallbackSetup, AutomaticFallbackFailure>)
              .value;
      expect(setup.btcAddress, _address);
      expect(setup.registeredNow, isTrue);
      expect(wallet.pendingCalls, 1);
      expect(wallet.freshCalls, 0);
      expect(wallet.labelCalls, 2);
      expect(service.lookupCalls, 2);
      expect(service.registerCalls, 1);
      expect(events, [
        'wallet',
        'lookup',
        'pending',
        'owns:$_address',
        'label:$_address',
        'register:$_address',
        'lookup',
        'owns:$_address',
        'label:$_address',
      ]);
    },
  );

  test(
    'first setup selects one fresh address when no pending label exists',
    () async {
      final events = <String>[];
      final wallet = _FakeWalletPort(events);
      final service = _FakeServicePort(events, [
        const Ok(BullnymRecoveryAddressLookupResult.unregistered()),
        Ok(_registered(_address)),
      ]);
      final usecase = EnsureAutomaticFallbackAddressUsecase(
        wallet: wallet,
        service: service,
      );

      final result = await usecase.execute();

      expect(
        result,
        isA<Ok<AutomaticFallbackSetup, AutomaticFallbackFailure>>(),
      );
      expect(wallet.pendingCalls, 1);
      expect(wallet.freshCalls, 1);
      expect(service.registerCalls, 1);
    },
  );

  test('unowned candidate is never labeled or registered', () async {
    final events = <String>[];
    final wallet = _FakeWalletPort(events)
      ..pendingResult = const Ok(_address)
      ..ownershipResult = const Ok(false);
    final service = _FakeServicePort(events, [
      const Ok(BullnymRecoveryAddressLookupResult.unregistered()),
    ]);
    final usecase = EnsureAutomaticFallbackAddressUsecase(
      wallet: wallet,
      service: service,
    );

    final result = await usecase.execute();

    expect(_failure(result).kind, AutomaticFallbackFailureKind.addressNotOwned);
    expect(wallet.labelCalls, 0);
    expect(service.registerCalls, 0);
  });

  test('label persistence failure stops before remote registration', () async {
    final events = <String>[];
    final wallet = _FakeWalletPort(events)
      ..pendingResult = const Ok(_address)
      ..labelResult = const Err(
        AutomaticFallbackFailure.labelPersistenceFailed(),
      );
    final service = _FakeServicePort(events, [
      const Ok(BullnymRecoveryAddressLookupResult.unregistered()),
    ]);
    final usecase = EnsureAutomaticFallbackAddressUsecase(
      wallet: wallet,
      service: service,
    );

    final result = await usecase.execute();

    expect(
      _failure(result).kind,
      AutomaticFallbackFailureKind.labelPersistenceFailed,
    );
    expect(service.registerCalls, 0);
  });

  test('registration failure leaves the labeled candidate for retry', () async {
    final events = <String>[];
    final wallet = _FakeWalletPort(events)..pendingResult = const Ok(_address);
    final service =
        _FakeServicePort(events, [
            const Ok(BullnymRecoveryAddressLookupResult.unregistered()),
          ])
          ..registerResult = const Err(
            AutomaticFallbackFailure.remoteRegistrationFailed(
              code: 'Timeout',
              retryable: true,
            ),
          );
    final usecase = EnsureAutomaticFallbackAddressUsecase(
      wallet: wallet,
      service: service,
    );

    final result = await usecase.execute();

    final failure = _failure(result);
    expect(failure.kind, AutomaticFallbackFailureKind.remoteRegistrationFailed);
    expect(failure.code, 'Timeout');
    expect(failure.retryable, isTrue);
    expect(wallet.labelCalls, 1);
    expect(service.registerCalls, 1);
  });

  test('different authenticated readback address fails integrity', () async {
    final events = <String>[];
    final wallet = _FakeWalletPort(events)..pendingResult = const Ok(_address);
    final service = _FakeServicePort(events, [
      const Ok(BullnymRecoveryAddressLookupResult.unregistered()),
      Ok(_registered(_otherAddress)),
    ]);
    final usecase = EnsureAutomaticFallbackAddressUsecase(
      wallet: wallet,
      service: service,
    );

    final result = await usecase.execute();

    expect(
      _failure(result).kind,
      AutomaticFallbackFailureKind.integrityMismatch,
    );
    expect(wallet.ownershipCalls, 1);
    expect(wallet.labelCalls, 1);
  });

  test(
    'failed post-registration readback keeps the labeled candidate',
    () async {
      final events = <String>[];
      final wallet = _FakeWalletPort(events)
        ..pendingResult = const Ok(_address);
      final service = _FakeServicePort(events, [
        const Ok(BullnymRecoveryAddressLookupResult.unregistered()),
        const Err(
          AutomaticFallbackFailure.remoteLookupFailed(
            code: 'Timeout',
            retryable: true,
          ),
        ),
      ]);
      final usecase = EnsureAutomaticFallbackAddressUsecase(
        wallet: wallet,
        service: service,
      );

      final result = await usecase.execute();

      final failure = _failure(result);
      expect(failure.kind, AutomaticFallbackFailureKind.remoteLookupFailed);
      expect(failure.retryable, isTrue);
      expect(wallet.labelCalls, 1);
      expect(service.registerCalls, 1);
      expect(service.lookupCalls, 2);
    },
  );

  test('remote lookup failure stops before local address selection', () async {
    final events = <String>[];
    final wallet = _FakeWalletPort(events);
    final service = _FakeServicePort(events, [
      const Err(
        AutomaticFallbackFailure.remoteLookupFailed(
          code: 'NetworkError',
          retryable: true,
        ),
      ),
    ]);
    final usecase = EnsureAutomaticFallbackAddressUsecase(
      wallet: wallet,
      service: service,
    );

    final result = await usecase.execute();

    expect(
      _failure(result).kind,
      AutomaticFallbackFailureKind.remoteLookupFailed,
    );
    expect(wallet.pendingCalls, 0);
    expect(wallet.freshCalls, 0);
  });

  test('invalid registered metadata fails before ownership checks', () async {
    final events = <String>[];
    final wallet = _FakeWalletPort(events);
    final service = _FakeServicePort(events, [
      Ok(_registered(_address, commitmentVersion: 0)),
    ]);
    final usecase = EnsureAutomaticFallbackAddressUsecase(
      wallet: wallet,
      service: service,
    );

    final result = await usecase.execute();

    expect(
      _failure(result).kind,
      AutomaticFallbackFailureKind.integrityMismatch,
    );
    expect(wallet.ownershipCalls, 0);
    expect(wallet.labelCalls, 0);
  });

  test('wallet context failure stops before authenticated lookup', () async {
    final events = <String>[];
    final wallet = _FakeWalletPort(events)
      ..contextResult = const Err(
        AutomaticFallbackFailure.noDefaultBitcoinWallet(),
      );
    final service = _FakeServicePort(events, const []);
    final usecase = EnsureAutomaticFallbackAddressUsecase(
      wallet: wallet,
      service: service,
    );

    final result = await usecase.execute();

    expect(
      _failure(result).kind,
      AutomaticFallbackFailureKind.noDefaultBitcoinWallet,
    );
    expect(service.lookupCalls, 0);
  });
}
