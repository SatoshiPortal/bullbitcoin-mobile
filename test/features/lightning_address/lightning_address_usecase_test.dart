import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/delete_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/nostr_identity/domain/derive_nostr_identity_handle_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip340/bip340.dart' as bip340;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:test/test.dart';

const _messageHashHex =
    '000102030405060708090a0b0c0d0e0f'
    '101112131415161718191a1b1c1d1e1f';

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

  test('register builds Bullnym auth signer and passes descriptor', () async {
    final usecase = RegisterLightningAddressUsecase(bullnym, nostrIdentity);

    final result = await usecase.execute(
      xprvBase58: xprv,
      nym: 'alice',
      ctDescriptor: 'ct-desc',
    );

    expect(result.nym, 'alice');
    expect(result.lightningAddress, 'alice@bullpay.ca');
    expect(bullnym.registerNym, 'alice');
    expect(bullnym.registerCtDescriptor, 'ct-desc');
    expect(
      bullnym.registerNpubHex,
      nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(xprv),
    );
    // Validity form, not byte-equality: BIP340 signatures are non-deterministic
    // under aux randomness, so assert the captured signature VERIFIES under the
    // bullnym-auth key over the signed hash rather than equals a re-signed one
    // (AD-6). This stays green when signing becomes randomized (pr20's later
    // conversion becomes an empty diff).
    _expectValidBullnymAuthSignature(
      signatureHex: bullnym.registerSignatureHex,
      xprv: xprv,
      nostrIdentity: nostrIdentity,
    );
  });

  test('delete builds Bullnym auth signer and deletes nym', () async {
    final usecase = DeleteLightningAddressRegistrationUsecase(
      bullnym,
      nostrIdentity,
    );

    await usecase.execute(xprvBase58: xprv, nym: 'alice');

    expect(bullnym.deleteNym, 'alice');
    expect(
      bullnym.deleteNpubHex,
      nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(xprv),
    );
    _expectValidBullnymAuthSignature(
      signatureHex: bullnym.deleteSignatureHex,
      xprv: xprv,
      nostrIdentity: nostrIdentity,
    );
  });

  test(
    'lookup returns active status for Bullnym active registration',
    () async {
      bullnym.lookupResult = const BullnymLookupResult(
        nym: 'alice',
        active: true,
        lightningAddress: 'alice@bullpay.ca',
      );
      final usecase = LookupLightningAddressRegistrationUsecase(bullnym);
      final npubHex = nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(
        xprv,
      );

      final status = await usecase.execute(npubHex: npubHex);

      expect(status.active, true);
      expect(status.nym, 'alice');
      expect(status.lightningAddress, 'alice@bullpay.ca');
      expect(bullnym.lookupNpubHex, npubHex);
    },
  );

  test(
    'lookup returns inactive status for Bullnym inactive registration',
    () async {
      bullnym.lookupResult = const BullnymLookupResult(
        nym: 'alice',
        active: false,
        lightningAddress: 'alice@bullpay.ca',
      );
      final usecase = LookupLightningAddressRegistrationUsecase(bullnym);
      final npubHex = nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(
        xprv,
      );

      final status = await usecase.execute(npubHex: npubHex);

      expect(status.active, false);
      expect(status.nym, 'alice');
      expect(status.lightningAddress, 'alice@bullpay.ca');
    },
  );

  test(
    'register rejects blank nym before deriving or calling Bullnym',
    () async {
      final usecase = RegisterLightningAddressUsecase(bullnym, nostrIdentity);

      expect(
        () => usecase.execute(
          xprvBase58: xprv,
          nym: '   ',
          ctDescriptor: 'ct-desc',
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
      bullnym,
      nostrIdentity,
    );

    expect(
      () => usecase.execute(xprvBase58: xprv, nym: ''),
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
    bullnym.registerError = const BullnymFailure.timeout(
      logMessage: 'server diagnostic',
    );
    final usecase = RegisterLightningAddressUsecase(bullnym, nostrIdentity);

    expect(
      () => usecase.execute(
        xprvBase58: xprv,
        nym: 'alice',
        ctDescriptor: 'ct-desc',
      ),
      throwsA(
        isA<LightningAddressException>()
            .having((e) => e.kind, 'kind', LightningAddressErrorKind.timeout)
            .having((e) => e.code, 'code', 'Timeout')
            .having((e) => e.retryable, 'retryable', true),
      ),
    );
  });

  test('maps Bullnym invalid input without blaming local nym validation', () {
    bullnym.registerError = const BullnymFailure.invalidInput(
      'server diagnostic',
    );
    final usecase = RegisterLightningAddressUsecase(bullnym, nostrIdentity);

    expect(
      () => usecase.execute(
        xprvBase58: xprv,
        nym: 'alice',
        ctDescriptor: 'ct-desc',
      ),
      throwsA(
        isA<LightningAddressException>()
            .having(
              (e) => e.kind,
              'kind',
              LightningAddressErrorKind.invalidRegistrationInput,
            )
            .having((e) => e.code, 'code', 'InvalidInput')
            .having((e) => e.retryable, 'retryable', false),
      ),
    );
  });
}

class _FakeBullnymFacade implements BullnymFacade {
  String? registerNym;
  String? registerCtDescriptor;
  String? registerNpubHex;
  String? registerSignatureHex;
  String? deleteNym;
  String? deleteNpubHex;
  String? deleteSignatureHex;
  String? lookupNpubHex;
  BullnymLookupResult lookupResult = const BullnymLookupResult(
    nym: 'alice',
    active: true,
  );
  BullnymFailure? registerError;

  @override
  Future<Result<BullnymVersionInfo, BullnymFailure>> getVersion() async =>
      const Ok(
        BullnymVersionInfo(publicNamePolicy: bullnymPermanentNamesV1Policy),
      );

  @override
  Future<Result<BullnymRegisterResult, BullnymFailure>> register({
    required BullnymAuthSigner signer,
    required String nym,
    required String ctDescriptor,
  }) async {
    final error = registerError;
    if (error != null) return Err(error);
    registerNym = nym;
    registerCtDescriptor = ctDescriptor;
    registerNpubHex = signer.npubHex;
    registerSignatureHex = await signer.signHashHex(_messageHashHex);
    return Ok(
      BullnymRegisterResult(nym: nym, lightningAddress: '$nym@bullpay.ca'),
    );
  }

  @override
  Future<Result<void, BullnymFailure>> deleteRegistration({
    required BullnymAuthSigner signer,
    required String nym,
  }) async {
    deleteNym = nym;
    deleteNpubHex = signer.npubHex;
    deleteSignatureHex = await signer.signHashHex(_messageHashHex);
    return const Ok(null);
  }

  @override
  Future<Result<BullnymLookupResult, BullnymFailure>> lookupRegistration({
    required String npubHex,
  }) async {
    lookupNpubHex = npubHex;
    return Ok(lookupResult);
  }

  @override
  Future<BullnymBackupHead> fetchBackup({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
  }) => throw UnimplementedError();

  @override
  Future<BullnymBackupStoreReceipt> storeBackup({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
    required AuthenticatedBackupCiphertext ciphertext,
  }) => throw UnimplementedError();

  @override
  Future<BullnymBackupDeleteReceipt?> deleteBackup({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
  }) => throw UnimplementedError();

  // Donation-page surface — not exercised by the Lightning Address usecases.
  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> getDonationPage({
    required String nym,
    required String kind,
  }) => throw UnimplementedError();

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> saveDonationPage({
    required BullnymAuthSigner signer,
    required String nym,
    required String ctDescriptor,
    required String header,
    required String description,
    required String displayCurrency,
    required String website,
    required String twitter,
    required String instagram,
    required bool enabled,
    required String kind,
    BullnymAliasIntent aliasIntent = const BullnymAliasIntent.preserve(),
  }) => throw UnimplementedError();

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> archiveDonationPage({
    required BullnymAuthSigner signer,
    required String nym,
    required String kind,
  }) => throw UnimplementedError();

  @override
  Future<Result<BullnymSupportedCurrencies, BullnymFailure>>
  getSupportedCurrencies() => throw UnimplementedError();

  // Recovery-address surface — not exercised by Lightning Address usecases.
  @override
  Future<Result<BullnymRecoveryAddressLookupResult, BullnymFailure>>
  lookupRecoveryAddress({required BullnymAuthSigner signer}) =>
      throw UnimplementedError();

  @override
  Future<Result<BullnymRecoveryAddressRegistrationResult, BullnymFailure>>
  registerRecoveryAddress({
    required BullnymAuthSigner signer,
    required String btcAddress,
  }) => throw UnimplementedError();

  // Invoice surface — not exercised by the Lightning Address usecases.
  @override
  Future<Result<BullnymCreateInvoiceResponse, BullnymFailure>> createInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required BullnymCreateInvoiceFields fields,
  }) => throw UnimplementedError();

  @override
  Future<Result<BullnymCancelInvoiceResponse, BullnymFailure>> cancelInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required String invoiceId,
  }) => throw UnimplementedError();

  @override
  Future<Result<BullnymListInvoicesResponse, BullnymFailure>> listInvoices({
    required BullnymAuthSigner signer,
    required int page,
    required int pageSize,
    String? status,
  }) => throw UnimplementedError();

  @override
  Future<Result<BullnymInvoiceStatus, BullnymFailure>> getInvoiceStatus({
    required String invoiceId,
  }) => throw UnimplementedError();
}

String _zeroMnemonicXprv() {
  final mnemonic = bip39.Mnemonic.fromSentence(
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    bip39.Language.english,
  );
  return bip32.Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed)).toBase58();
}

/// Asserts the captured bullnym-auth signature is a well-formed BIP340
/// signature that verifies under the bullnym server-auth key over the signed
/// hash - validity, not byte-equality (AD-6). Uses the independent bip340
/// package as the verifier.
void _expectValidBullnymAuthSignature({
  required String? signatureHex,
  required String xprv,
  required NostrIdentityFacade nostrIdentity,
}) {
  expect(signatureHex, isNotNull);
  expect(signatureHex!.length, 128, reason: '64-byte BIP340 signature');
  expect(
    bip340.verify(
      nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(xprv),
      _messageHashHex,
      signatureHex,
    ),
    isTrue,
  );
}
