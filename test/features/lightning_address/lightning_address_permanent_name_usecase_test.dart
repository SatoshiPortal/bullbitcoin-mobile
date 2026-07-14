import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_nym_validation.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/deactivate_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/delete_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/get_lightning_address_permanent_name_capability_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lightning_address_error_mapping.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_registration_usecase.dart';
import 'package:test/test.dart';

void main() {
  group('permanent nym validation', () {
    test('trims and lowercases before returning signed wire value', () {
      expect(validateLightningAddressNym('  Alice-21  '), 'alice-21');
      expect(normalizeLightningAddressNym('  ALICE  '), 'alice');
    });

    test('rejects exact server reservations distinctly', () {
      expect(
        () => validateLightningAddressNym('REGISTER'),
        throwsA(
          isA<LightningAddressException>()
              .having(
                (error) => error.kind,
                'kind',
                LightningAddressErrorKind.reservedNym,
              )
              .having((error) => error.code, 'code', 'NymReserved'),
        ),
      );
    });

    for (final value in ['', '-alice', 'alice-', 'ali_ce', 'alice bob']) {
      test('rejects invalid syntax: "$value"', () {
        expect(
          () => validateLightningAddressNym(value),
          throwsA(
            isA<LightningAddressException>().having(
              (error) => error.kind,
              'kind',
              LightningAddressErrorKind.invalidNym,
            ),
          ),
        );
      });
    }
  });

  group('permanent-name capability', () {
    test('enables only exact permanent_names_v1', () async {
      final bullnym = _FakeBullnymFacade();
      final usecase = GetLightningAddressPermanentNameCapabilityUsecase(
        bullnym,
      );

      expect(await usecase.execute(), isTrue);
      bullnym.version = const BullnymVersionInfo(
        publicNamePolicy: 'permanent_names_v2',
      );
      expect(await usecase.execute(), isFalse);
      bullnym.version = const BullnymVersionInfo(publicNamePolicy: null);
      expect(await usecase.execute(), isFalse);
    });

    test('maps capability failures without exposing diagnostics', () async {
      final bullnym = _FakeBullnymFacade()
        ..versionFailure = const BullnymFailure.network(
          logMessage: 'private network diagnostic',
        );
      final usecase = GetLightningAddressPermanentNameCapabilityUsecase(
        bullnym,
      );

      await expectLater(
        usecase.execute(),
        throwsA(
          isA<LightningAddressException>()
              .having(
                (error) => error.kind,
                'kind',
                LightningAddressErrorKind.network,
              )
              .having(
                (error) => error.toString(),
                'safe string',
                isNot(contains('private network diagnostic')),
              ),
        ),
      );
    });
  });

  group('lookup permanent-name projection', () {
    test(
      'projects exact typed status and quota for Lightning Address',
      () async {
        final bullnym = _FakeBullnymFacade()
          ..lookup = BullnymLookupResult(
            nym: 'compatibility-nym',
            active: false,
            lightningAddress: 'alice@pay2.bull-wallet.com',
            publicNameStatus: BullnymPublicNameStatus(
              nym: BullnymPublicName('alice'),
              alias: BullnymPublicName('coffee'),
              lightningAddressOnline: true,
              publicNamePolicy: bullnymPermanentNamesV1Policy,
              quota: BullnymQuota(used: 1, cap: 1, remaining: 0),
            ),
          );
        final usecase = LookupLightningAddressRegistrationUsecase(bullnym);

        final result = await usecase.execute(npubHex: 'aa' * 32);

        expect(result.nym, 'alice');
        expect(result.active, isTrue);
        expect(result.lightningAddress, 'alice@pay2.bull-wallet.com');
        expect(result.permanentNameStatus?.nym, 'alice');
        expect(result.permanentNameStatus?.lightningAddressOnline, isTrue);
        expect(result.permanentNameStatus?.quota.used, 1);
        expect(result.permanentNameStatus?.quota.cap, 1);
        expect(result.permanentNameStatus?.quota.remaining, 0);
      },
    );

    test('legacy lookup never invents permanent-name ownership', () async {
      final bullnym = _FakeBullnymFacade()
        ..lookup = const BullnymLookupResult(nym: 'alice', active: true);
      final usecase = LookupLightningAddressRegistrationUsecase(bullnym);

      final result = await usecase.execute(npubHex: 'aa' * 32);

      expect(result.nym, 'alice');
      expect(result.active, isTrue);
      expect(result.permanentNameStatus, isNull);
    });
  });

  test('structured NymAlreadyAssigned preserves only the owned nym', () {
    final mapped = mapBullnymToLightningAddressException(
      BullnymFailure.serverRejectedRequest(
        code: 'NymAlreadyAssigned',
        logMessage: 'private reason that must not escape',
        statusCode: 409,
        retryable: false,
        ownedNameDetails: BullnymOwnedNymDetails(
          nym: BullnymPublicName('alice'),
          domain: 'pay2.bull-wallet.com',
        ),
      ),
    );

    expect(mapped, isA<LightningAddressServerRejectedRequestException>());
    expect(
      (mapped as LightningAddressServerRejectedRequestException).ownedNym,
      'alice',
    );
    expect(mapped.toString(), isNot(contains('private reason')));
  });

  test(
    'wallet-owned deactivation derives auth material and keeps same nym',
    () async {
      final xprv = _FakeDefaultWalletXprv();
      final delete = _FakeDelete();
      final usecase = DeactivateWalletOwnedLightningAddressUsecase(
        defaultWalletXprv: xprv,
        delete: delete,
      );

      await usecase.execute(nym: '  ALICE  ');

      expect(xprv.calls, 1);
      expect(delete.xprvs, ['test-xprv']);
      expect(delete.nyms, ['alice']);
    },
  );
}

class _FakeBullnymFacade implements BullnymFacade {
  BullnymVersionInfo version = const BullnymVersionInfo(
    publicNamePolicy: bullnymPermanentNamesV1Policy,
  );
  BullnymFailure? versionFailure;
  BullnymLookupResult lookup = const BullnymLookupResult(
    nym: 'alice',
    active: true,
  );

  @override
  Future<Result<BullnymVersionInfo, BullnymFailure>> getVersion() async {
    final failure = versionFailure;
    return failure == null ? Ok(version) : Err(failure);
  }

  @override
  Future<Result<BullnymLookupResult, BullnymFailure>> lookupRegistration({
    required String npubHex,
  }) async => Ok(lookup);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDefaultWalletXprv implements LightningAddressDefaultWalletXprvPort {
  int calls = 0;

  @override
  Future<String> deriveDefaultWalletXprv() async {
    calls += 1;
    return 'test-xprv';
  }
}

class _FakeDelete implements DeleteLightningAddressRegistrationUsecase {
  final xprvs = <String>[];
  final nyms = <String>[];

  @override
  Future<void> execute({
    required String xprvBase58,
    required String nym,
  }) async {
    xprvs.add(xprvBase58);
    nyms.add(nym);
  }
}
