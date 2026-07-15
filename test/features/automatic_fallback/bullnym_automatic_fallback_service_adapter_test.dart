import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/automatic_fallback/data/bullnym_automatic_fallback_service_adapter.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_failure.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBullnymFacade extends Mock implements BullnymFacade {}

void main() {
  final signer = BullnymAuthSigner(
    npubHex: 'fixture-npub',
    signHashHex: (_) => 'fixture-signature',
  );
  late _MockBullnymFacade bullnym;
  late BullnymAutomaticFallbackServiceAdapter adapter;

  setUp(() {
    bullnym = _MockBullnymFacade();
    adapter = BullnymAutomaticFallbackServiceAdapter(bullnym: bullnym);
  });

  test('passes a typed authenticated lookup result through', () async {
    const lookup = BullnymRecoveryAddressLookupResult(
      version: bullnymRecoveryAddressContractVersion,
      isRegistered: true,
      btcAddress: 'bc1qfallback',
      commitmentVersion: 1,
      signedAtUnix: 1_700_000_000,
    );
    when(
      () => bullnym.lookupRecoveryAddress(signer: signer),
    ).thenAnswer((_) async => const Ok(lookup));

    final result = await adapter.lookup(signer: signer);

    expect(
      (result
              as Ok<
                BullnymRecoveryAddressLookupResult,
                AutomaticFallbackFailure
              >)
          .value,
      same(lookup),
    );
  });

  test(
    'maps lookup diagnostics to stable code and retryability only',
    () async {
      when(() => bullnym.lookupRecoveryAddress(signer: signer)).thenAnswer(
        (_) async => const Err(
          BullnymFailure.network(logMessage: 'private transport diagnostic'),
        ),
      );

      final result = await adapter.lookup(signer: signer);

      final failure =
          (result
                  as Err<
                    BullnymRecoveryAddressLookupResult,
                    AutomaticFallbackFailure
                  >)
              .failure;
      expect(failure.kind, AutomaticFallbackFailureKind.remoteLookupFailed);
      expect(failure.code, 'NetworkError');
      expect(failure.retryable, isTrue);
      expect(failure.logMessage, isNull);
    },
  );

  test('maps registration failure without exposing backend reason', () async {
    when(
      () => bullnym.registerRecoveryAddress(
        signer: signer,
        btcAddress: 'bc1qfallback',
      ),
    ).thenAnswer(
      (_) async => const Err(
        BullnymFailure.serverRejectedRequest(
          code: 'RecoveryAddressConflict',
          logMessage: 'private backend reason',
          statusCode: 409,
          retryable: false,
        ),
      ),
    );

    final result = await adapter.register(
      signer: signer,
      btcAddress: 'bc1qfallback',
    );

    final failure =
        (result
                as Err<
                  BullnymRecoveryAddressRegistrationResult,
                  AutomaticFallbackFailure
                >)
            .failure;
    expect(failure.kind, AutomaticFallbackFailureKind.remoteRegistrationFailed);
    expect(failure.code, 'RecoveryAddressConflict');
    expect(failure.retryable, isFalse);
    expect(failure.logMessage, isNull);
  });
}
