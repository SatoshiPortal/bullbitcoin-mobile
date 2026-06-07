import 'dart:typed_data';

import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/application/usecases/delete_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/application/usecases/lookup_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/application/usecases/register_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/nostr_identity/domain/derive_nostr_identity_handle_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:test/test.dart';

void main() {
  late String xprv;
  late NostrIdentityFacade nostrIdentity;
  late _FakeBullnymFacade bullnym;

  setUp(() {
    xprv = _zeroMnemonicXprv();
    nostrIdentity = const NostrIdentityFacade(
      deriveHandle: DeriveNostrIdentityHandleUsecase(
        registry: Bip85RegistryFacade(),
      ),
    );
    bullnym = _FakeBullnymFacade();
  });

  test('register derives Bullnym auth handle and passes descriptor', () async {
    final usecase = RegisterLightningAddressUsecase(
      bullnym: bullnym,
      nostrIdentity: nostrIdentity,
    );

    final result = await usecase.execute(
      RegisterLightningAddressCommand(
        xprvBase58: xprv,
        nym: 'alice',
        ctDescriptor: 'ct-desc',
      ),
    );

    expect(result.nym, 'alice');
    expect(result.lightningAddress, 'alice@bullpay.ca');
    expect(bullnym.registerNym, 'alice');
    expect(bullnym.registerCtDescriptor, 'ct-desc');
    expect(
      bullnym.registerNpubHex,
      nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(xprv),
    );
  });

  test('delete derives Bullnym auth handle and deletes nym', () async {
    final usecase = DeleteLightningAddressRegistrationUsecase(
      bullnym: bullnym,
      nostrIdentity: nostrIdentity,
    );

    await usecase.execute(
      DeleteLightningAddressRegistrationCommand(xprvBase58: xprv, nym: 'alice'),
    );

    expect(bullnym.deleteNym, 'alice');
    expect(
      bullnym.deleteNpubHex,
      nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(xprv),
    );
  });

  test(
    'lookup returns active status for Bullnym active registration',
    () async {
      bullnym.lookupResult = const BullnymLookupResult(
        nym: 'alice',
        active: true,
      );
      final usecase = LookupLightningAddressRegistrationUsecase(
        bullnym: bullnym,
        nostrIdentity: nostrIdentity,
      );

      final status = await usecase.execute(xprvBase58: xprv);

      expect(status.active, true);
      expect(status.nym, 'alice');
      expect(
        bullnym.lookupNpubHex,
        nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(xprv),
      );
    },
  );

  test(
    'lookup returns inactive status for Bullnym inactive registration',
    () async {
      bullnym.lookupResult = const BullnymLookupResult(
        nym: 'alice',
        active: false,
      );
      final usecase = LookupLightningAddressRegistrationUsecase(
        bullnym: bullnym,
        nostrIdentity: nostrIdentity,
      );

      final status = await usecase.execute(xprvBase58: xprv);

      expect(status.active, false);
      expect(status.nym, 'alice');
    },
  );

  test(
    'register rejects blank nym before deriving or calling Bullnym',
    () async {
      final usecase = RegisterLightningAddressUsecase(
        bullnym: bullnym,
        nostrIdentity: nostrIdentity,
      );

      expect(
        () => usecase.execute(
          RegisterLightningAddressCommand(
            xprvBase58: xprv,
            nym: '   ',
            ctDescriptor: 'ct-desc',
          ),
        ),
        throwsA(
          isA<LightningAddressException>().having(
            (e) => e.kind,
            'kind',
            LightningAddressErrorKind.invalidNym,
          ),
        ),
      );
      expect(bullnym.registerNym, isNull);
    },
  );

  test('delete rejects blank nym before deriving or calling Bullnym', () async {
    final usecase = DeleteLightningAddressRegistrationUsecase(
      bullnym: bullnym,
      nostrIdentity: nostrIdentity,
    );

    expect(
      () => usecase.execute(
        DeleteLightningAddressRegistrationCommand(xprvBase58: xprv, nym: ''),
      ),
      throwsA(
        isA<LightningAddressException>().having(
          (e) => e.kind,
          'kind',
          LightningAddressErrorKind.invalidNym,
        ),
      ),
    );
    expect(bullnym.deleteNym, isNull);
  });

  test('maps Bullnym errors without leaking diagnostics', () async {
    bullnym.registerError = const BullnymException.timeout(
      diagnosticReason: 'server diagnostic',
    );
    final usecase = RegisterLightningAddressUsecase(
      bullnym: bullnym,
      nostrIdentity: nostrIdentity,
    );

    expect(
      () => usecase.execute(
        RegisterLightningAddressCommand(
          xprvBase58: xprv,
          nym: 'alice',
          ctDescriptor: 'ct-desc',
        ),
      ),
      throwsA(
        isA<LightningAddressException>()
            .having((e) => e.kind, 'kind', LightningAddressErrorKind.timeout)
            .having((e) => e.code, 'code', 'Timeout')
            .having((e) => e.retryable, 'retryable', true),
      ),
    );
  });
}

class _FakeBullnymFacade implements BullnymFacade {
  String? registerNym;
  String? registerCtDescriptor;
  String? registerNpubHex;
  String? deleteNym;
  String? deleteNpubHex;
  String? lookupNpubHex;
  BullnymLookupResult lookupResult = const BullnymLookupResult(
    nym: 'alice',
    active: true,
  );
  BullnymException? registerError;

  @override
  Future<BullnymRegisterResult> register({
    required BullnymAuthSigner signer,
    required String nym,
    required String ctDescriptor,
  }) async {
    final error = registerError;
    if (error != null) throw error;
    registerNym = nym;
    registerCtDescriptor = ctDescriptor;
    registerNpubHex = signer.npubHex;
    return BullnymRegisterResult(nym: nym, lightningAddress: '$nym@bullpay.ca');
  }

  @override
  Future<void> deleteRegistration({
    required BullnymAuthSigner signer,
    required String nym,
  }) async {
    deleteNym = nym;
    deleteNpubHex = signer.npubHex;
  }

  @override
  Future<BullnymLookupResult> lookupRegistration({
    required String npubHex,
  }) async {
    lookupNpubHex = npubHex;
    return lookupResult;
  }
}

String _zeroMnemonicXprv() {
  final mnemonic = bip39.Mnemonic.fromSentence(
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    bip39.Language.english,
  );
  return bip32.Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed)).toBase58();
}
