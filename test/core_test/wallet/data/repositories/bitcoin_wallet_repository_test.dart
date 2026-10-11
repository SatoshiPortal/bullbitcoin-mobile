import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'dart:io';

import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:drift_dev/api/migrations_native.dart';
import '../../../../migrations_test/bull_database/generated/schema.dart';
import '../../../../migrations_test/bull_database/generated/schema_v15.dart'
    as v15;

import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_signer_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_psbt_review_exception.dart';
import 'package:bb_mobile/core/wallet/domain/manipulated_transaction_exception.dart';
import 'package:bb_mobile/core/wallet/domain/transaction_signature_status.dart';
import 'package:bb_mobile/core/wallet/domain/unverifiable_transaction_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_input_parser.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../bdk_wallet_test_fixture.dart';
import '../../wallet_signer_test_fixture.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockFrozenWalletUtxoDatasource extends Mock
    implements FrozenWalletUtxoDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockElectrumServersPort extends Mock implements ElectrumServersPort {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockSeedVerificationPort extends Mock implements SeedVerificationPort {}

class _SigningTestBdkWalletDatasource extends BdkWalletDatasource {
  TransactionSignatureStatus signatureStatus = TransactionSignatureStatus.valid;
  String? replacementPsbt;

  @override
  Future<TransactionSignatureStatus> verifyTransactionInputSignatures({
    required String txid,
    required WalletModel wallet,
  }) async => signatureStatus;

  @override
  Future<String> createUnsignedReplaceByFeePsbt({
    required WalletModel wallet,
    required String txid,
    required RelativeFee feeRate,
  }) async {
    final replacement = replacementPsbt;
    if (replacement != null) return replacement;
    return super.createUnsignedReplaceByFeePsbt(
      wallet: wallet,
      txid: txid,
      feeRate: feeRate,
    );
  }

  @override
  Future<void> validateWalletPsbtInputs(
    String psbtBase64, {
    required PublicBdkWalletModel wallet,
    Set<String> frozenOutpoints = const {},
    String? replacingTxid,
    bool allowSpentWalletInputs = false,
  }) async {}
}

class _TestPathProvider extends PathProviderPlatform {
  final String path;

  _TestPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

typedef _SignerFixture = ({
  String externalPublic,
  String fingerprint,
  String internalPublic,
  String words,
  String? passphrase,
  String xpub,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WalletMetadataDatasource metadataDatasource;
  late Secrets secrets;
  late BdkWalletDatasource bdkDatasource;
  late FrozenWalletUtxoDatasource frozenWalletUtxoDatasource;
  late BitcoinWalletRepository repository;
  late Directory tempDirectory;
  late PathProviderPlatform originalPathProvider;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync(
      'bitcoin_wallet_repository_',
    );
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPathProvider(tempDirectory.path);
    metadataDatasource = _MockWalletMetadataDatasource();
    FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => tempDirectory.path);
    bdkDatasource = _SigningTestBdkWalletDatasource();
    frozenWalletUtxoDatasource = _MockFrozenWalletUtxoDatasource();
    when(
      () => frozenWalletUtxoDatasource.getAllFrozen(),
    ).thenAnswer((_) async => const []);
    repository = BitcoinWalletRepository(
      walletMetadataDatasource: metadataDatasource,
      secrets: secrets,
      bdkWalletDatasource: bdkDatasource,
      frozenWalletUtxoDatasource: frozenWalletUtxoDatasource,
    );
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    tempDirectory.deleteSync(recursive: true);
  });

  Future<void> stubWallet(
    WalletMetadataModel metadata,
    List<_SignerFixture> localSigners,
  ) async {
    when(
      () => metadataDatasource.fetch(metadata.id),
    ).thenAnswer((_) async => metadata);
    for (final signer in localSigners) {
      final imported = await secrets.import(
        words: signer.words.split(' '),
        passphrase: signer.passphrase,
      );
      switch (imported) {
        case Ok(:final value):
          expect(value.id.hex, signer.fingerprint);
        case Err(failure: SecretAlreadyExistsFailure(:final id)):
          expect(id.hex, signer.fingerprint);
        case Err(:final failure):
          fail('Secret import failed: ${failure.runtimeType}');
      }
    }
  }

  for (final scriptType in [ScriptType.bip49, ScriptType.bip84]) {
    for (final migrated in [false, true]) {
      test(
        'signs a ${migrated ? 'migrated' : 'fresh'} ${scriptType.name} mobile wallet',
        () async {
          final signer = _singleSignatureFixture(
            testMnemonics.first,
            scriptType: scriptType,
          );
          var metadata = await WalletMetadataService.deriveFromSecret(
            secret:
                (await secrets.import(words: signer.words.split(' '))
                        as Ok<Secret, SecretFailure>)
                    .value,
            network: Network.bitcoinTestnet,
            scriptType: scriptType,
            isDefault: true,
          );
          if (migrated) metadata = await _migrateMetadata(metadata, signer);
          expect(
            metadata.signers.single.descriptorKeys.single.xpub,
            startsWith(scriptType == ScriptType.bip49 ? 'upub' : 'vpub'),
          );
          await stubWallet(metadata, [signer]);
          final unsignedPsbt = buildUnsignedPsbt(
            descriptor: metadata.publicDescriptor,
          );
          final signed = _unwrapSigning(
            await repository.signPsbt(unsignedPsbt, walletId: metadata.id),
          );
          expect(signed.isFinalized, isTrue);
        },
      );
    }
  }

  test('signs a local wallet at its stored account index', () async {
    const account = 1;
    final signer = _singleSignatureFixture(
      testMnemonics.first,
      account: account,
    );
    final metadata = _metadata(
      descriptor: twoPathDescriptor(
        signer.externalPublic,
        signer.internalPublic,
      ),
      signers: [signer],
      localSignerCount: 1,
      derivationPath: "m/84'/1'/$account'",
    );
    await stubWallet(metadata, [signer]);

    final unsigned = buildUnsignedPsbt(descriptor: metadata.publicDescriptor);
    final signed = _unwrapSigning(
      await repository.signPsbt(unsigned, walletId: metadata.id),
    );
    expect(signed.isFinalized, isTrue);
  });

  test(
    'fee bump requires verified inputs and signs the stored account',
    () async {
      final signer = _singleSignatureFixture(testMnemonics.first, account: 1);
      final metadata = _metadata(
        descriptor: twoPathDescriptor(
          signer.externalPublic,
          signer.internalPublic,
        ),
        signers: [signer],
        localSignerCount: 1,
        derivationPath: "m/84'/1'/1'",
      );
      await stubWallet(metadata, [signer]);
      final datasource = bdkDatasource as _SigningTestBdkWalletDatasource;
      datasource.replacementPsbt = buildUnsignedPsbt(
        descriptor: metadata.publicDescriptor,
      );
      Future<String> bump() => repository.bumpFee(
        walletId: metadata.id,
        txid: 'original',
        newFeeRate: const RelativeFee(2500),
      );

      datasource.signatureStatus = TransactionSignatureStatus.invalid;
      await expectLater(
        bump(),
        throwsA(isA<ManipulatedTransactionException>()),
      );
      datasource.signatureStatus = TransactionSignatureStatus.unverifiable;
      await expectLater(
        bump(),
        throwsA(isA<UnverifiableTransactionException>()),
      );
      datasource.signatureStatus = TransactionSignatureStatus.valid;
      final signed = bdk.Psbt(psbtBase64: await bump());
      try {
        expect(signed.input().single.finalScriptWitness, isNotEmpty);
      } finally {
        signed.dispose();
      }
    },
  );

  test('preserves an existing PSBT when adding a local signature', () async {
    final signer = _singleSignatureFixture(testMnemonics.first);
    final metadata = _metadata(
      descriptor: twoPathDescriptor(
        signer.externalPublic,
        signer.internalPublic,
      ),
      signers: [signer],
      localSignerCount: 1,
    );
    await stubWallet(metadata, [signer]);
    final unsignedPsbt = buildUnsignedPsbt(
      descriptor: twoPathDescriptor(
        signer.externalPublic,
        signer.internalPublic,
      ),
    );

    final signed = _unwrapSigning(
      await repository.signPsbt(
        unsignedPsbt,
        walletId: metadata.id,
        tryFinalize: false,
      ),
    );

    expect(signed.isFinalized, isFalse);
    expect(signedFingerprints(signed.psbt), {signer.fingerprint.toLowerCase()});
  });

  test('adds a partial signature for a delayed Miniscript path', () async {
    final remote = _multisigFixture(testMnemonics.first);
    final local = _miniscriptBip84Fixture(testMnemonics[1]);
    final externalDescriptor = bdk.Descriptor.newWsh(
      miniScript:
          'or_d(pk(${remote.externalPublic}),and_v(v:pkh(${local.externalPublic}),older(1)))',
    ).toString();
    final internalDescriptor = bdk.Descriptor.newWsh(
      miniScript:
          'or_d(pk(${remote.internalPublic}),and_v(v:pkh(${local.internalPublic}),older(1)))',
    ).toString();
    final metadata = WalletMetadataModel(
      id: 'wallet',
      network: Network.bitcoinTestnet,
      signers: [
        walletSignerModel(
          id: 'signer-0',
          descriptorKeyId: 'key-0',
          masterFingerprint: remote.fingerprint,
          xpubFingerprint: remote.fingerprint,
          xpub: remote.xpub,
          derivationPath: "m/48'/1'/0'/2'",
          signer: Signer.remote,
          signerDevice: null,
        ),
        walletSignerModel(
          id: 'signer-1',
          descriptorKeyId: 'key-1',
          masterFingerprint: local.fingerprint,
          xpubFingerprint: local.fingerprint,
          xpub: local.xpub,
          derivationPath: "m/84'/1'/0'",
          signer: Signer.local,
          signerDevice: null,
        ),
      ],
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      publicDescriptor: twoPathDescriptor(
        externalDescriptor,
        internalDescriptor,
      ),
      isDefault: false,
    );
    await stubWallet(metadata, [local]);
    final policy = _unwrapSigning(
      await repository.getPolicy(walletId: metadata.id),
    );
    final selector = policy
        .pathSelectors(const BitcoinPolicySelection.empty())
        .single;
    final delayedIndex = selector.options.indexWhere(
      containsPolicyNode<BitcoinRelativeTimelockPolicyNode>,
    );
    final selection = policy.select(
      current: const BitcoinPolicySelection.empty(),
      requirement: selector,
      selectedIndices: {delayedIndex},
    );
    final unsignedPsbt = buildUnsignedPsbt(
      descriptor: twoPathDescriptor(externalDescriptor, internalDescriptor),
      policyPath: policy.buildPath(selection),
    );

    final signed = _unwrapSigning(
      await repository.signPsbt(
        unsignedPsbt,
        walletId: metadata.id,
        tryFinalize: false,
      ),
    );

    expect(signed.isFinalized, isFalse);
    expect(signedFingerprints(signed.psbt), {local.fingerprint.toLowerCase()});
  });

  test('one local multisig key returns a partial PSBT', () async {
    final signers = testMnemonics.map(_multisigFixture).toList();
    final metadata = _multisigMetadata(signers, localSignerCount: 1);
    await stubWallet(metadata, signers.take(1).toList());
    final unsignedPsbt = buildUnsignedPsbt(
      descriptor: metadata.publicDescriptor,
    );

    final signed = _unwrapSigning(
      await repository.signPsbt(unsignedPsbt, walletId: metadata.id),
    );

    expect(signed.isFinalized, isFalse);
    expect(bdkDatasource.finalizePsbt(signed.psbt).isFinalized, isFalse);
  });

  test('enough local multisig keys finalize the PSBT', () async {
    final signers = testMnemonics.map(_multisigFixture).toList();
    final metadata = _multisigMetadata(signers, localSignerCount: 2);
    await stubWallet(metadata, signers.take(2).toList());
    final unsignedPsbt = buildUnsignedPsbt(
      descriptor: metadata.publicDescriptor,
    );

    final signed = _unwrapSigning(
      await repository.signPsbt(unsignedPsbt, walletId: metadata.id),
    );

    expect(signed.isFinalized, isTrue);
  });

  test('imports and signs repeated account keys with mixed origins', () async {
    final signer = _multisigFixture(testMnemonics.first);
    final descriptorKey = "[${signer.fingerprint}/48'/1'/0'/2']${signer.xpub}";
    final descriptor =
        'wsh(sortedmulti(2,$descriptorKey/0/<0;1>/*,'
        '${signer.xpub}/1/<0;1>/*))';
    final lwk = _MockLwkWalletDatasource();
    when(
      () => lwk.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());
    final wallets = WalletRepository(
      walletMetadataDatasource: metadataDatasource,
      bdkWalletDatasource: bdkDatasource,
      lwkWalletDatasource: lwk,
      serversPort: _MockElectrumServersPort(),
    );
    final settings = _MockGetSettingsUsecase();
    when(settings.execute).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    final seedVerification = _MockSeedVerificationPort();
    when(
      () => seedVerification.matchesXpubs(
        fingerprint: signer.fingerprint,
        keys: any(named: 'keys'),
      ),
    ).thenAnswer((_) async => true);
    final parser = ParseWatchOnlyInputUsecase(
      WatchOnlyInputParser(wallets),
      settings,
      seedVerification,
    );
    final parsed =
        (await parser.execute(descriptor)
                    as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>)
                .value
            as WatchOnlyDescriptorEntity;
    registerFallbackValue(
      _metadata(descriptor: descriptor, signers: [signer], localSignerCount: 1),
    );
    late WalletMetadataModel metadata;
    when(metadataDatasource.fetchAll).thenAnswer((_) async => []);
    when(() => metadataDatasource.store(any())).thenAnswer((invocation) async {
      metadata = invocation.positionalArguments.single as WalletMetadataModel;
    });
    final imported = await wallets.importDescriptor(
      descriptor: parsed.descriptor,
      network: parsed.network,
      label: 'Shared account',
      signers: parsed.signers,
    );
    expect(imported.signers, hasLength(1));
    expect(imported.signers.single.descriptorKeys, hasLength(2));
    expect(
      imported.signers.single.descriptorKeys.map((key) => key.derivationPath),
      everyElement("m/48'/1'/0'/2'"),
    );
    await stubWallet(metadata, [signer]);
    final unsignedPsbt = buildUnsignedPsbt(descriptor: descriptor);

    final signed = _unwrapSigning(
      await repository.signPsbt(unsignedPsbt, walletId: metadata.id),
    );

    expect(signed.isFinalized, isTrue);
  });

  test('signs only the selected Taproot policy branch', () async {
    final local = _bip48Fixture(testMnemonics.first);
    final remote = _bip48Fixture(testMnemonics[1]);
    final localKey = "[${local.fingerprint}/48'/1'/0'/2']${local.xpub}";
    final remoteKey = "[${remote.fingerprint}/48'/1'/0'/2']${remote.xpub}";
    final descriptor =
        'tr($_numsKey,{multi_a(2,$localKey/<0;1>/*,'
        '$remoteKey/<0;1>/*),'
        'and_v(v:after(2000000000),pk($localKey/<2;3>/*))})';
    final metadata = WalletMetadataModel(
      id: 'wallet',
      network: Network.bitcoinTestnet,
      signers: [
        WalletSignerModel(
          id: 'signer-0',
          signer: Signer.local,
          signerDevice: null,
          descriptorKeys: [
            for (final (index, descriptorPath) in [
              '/<0;1>/*',
              '/<2;3>/*',
            ].indexed)
              WalletDescriptorKeyModel(
                id: 'local-key-$index',
                signerId: 'signer-0',
                masterFingerprint: local.fingerprint,
                xpubFingerprint: local.fingerprint,
                xpub: local.xpub,
                derivationPath: "m/48'/1'/0'/2'",
                descriptorPath: descriptorPath,
              ),
          ],
        ),
        walletSignerModel(
          id: 'signer-1',
          descriptorKeyId: 'remote-key-0',
          masterFingerprint: remote.fingerprint,
          xpubFingerprint: remote.fingerprint,
          xpub: remote.xpub,
          derivationPath: "m/48'/1'/0'/2'",
          descriptorPath: '/<0;1>/*',
          signer: Signer.remote,
          signerDevice: null,
        ),
      ],
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      publicDescriptor: descriptor,
      isDefault: false,
    );
    await stubWallet(metadata, [local]);
    final policy = _unwrapSigning(
      await repository.getPolicy(walletId: metadata.id),
    );
    final selector = policy
        .pathSelectors(const BitcoinPolicySelection.empty())
        .single;
    final immediateIndex = selector.options.indexWhere(
      (option) =>
          !containsPolicyNode<BitcoinAbsoluteTimelockPolicyNode>(option),
    );
    final selection = policy.select(
      current: const BitcoinPolicySelection.empty(),
      requirement: selector,
      selectedIndices: {immediateIndex},
    );
    final unsignedPsbt = buildUnsignedPsbt(
      descriptor: descriptor,
      policyPath: policy.buildPath(selection),
    );

    final signed = _unwrapSigning(
      await repository.signPsbt(
        unsignedPsbt,
        walletId: metadata.id,
        tryFinalize: false,
      ),
    );

    expect(
      () => bdkDatasource.validateExternalPartialPsbt(
        currentPsbtBase64: unsignedPsbt,
        signedPsbtBase64: signed.psbt,
      ),
      returnsNormally,
    );
  });

  test('signs with only the selected local multisig key', () async {
    final signers = testMnemonics.map(_multisigFixture).toList();
    final metadata = _multisigMetadata(signers, localSignerCount: 2);
    await stubWallet(metadata, signers.take(2).toList());
    final unsignedPsbt = buildUnsignedPsbt(
      descriptor: metadata.publicDescriptor,
    );

    final signed = _unwrapSigning(
      await repository.signPsbt(
        unsignedPsbt,
        walletId: metadata.id,
        tryFinalize: false,
        signerId: 'signer-1',
      ),
    );

    expect(signedFingerprints(signed.psbt), {
      signers[1].fingerprint.toLowerCase(),
    });
  });

  test('requires the matching passphrase for a protected local key', () async {
    const passphrase = 'vault passphrase';
    final canonical = _bip48Fixture(testMnemonics.first);
    final protected = _bip48Fixture(
      testMnemonics.first,
      passphrase: passphrase,
    );
    final descriptor =
        "wsh(pk([${protected.fingerprint}/48'/1'/0'/2']${protected.xpub}/<0;1>/*))";
    final metadata = WalletMetadataModel(
      id: 'wallet',
      network: Network.bitcoinTestnet,
      signers: [
        WalletSignerModel(
          id: 'signer-0',
          signer: Signer.local,
          signerDevice: null,
          localSeedFingerprint: canonical.fingerprint,
          descriptorKeys: [
            WalletDescriptorKeyModel(
              id: 'key-0',
              signerId: 'signer-0',
              masterFingerprint: protected.fingerprint,
              xpubFingerprint: protected.fingerprint,
              xpub: protected.xpub,
              derivationPath: "m/48'/1'/0'/2'",
              descriptorPath: '/<0;1>/*',
              requiresPassphrase: true,
            ),
          ],
        ),
      ],
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      publicDescriptor: descriptor,
      isDefault: false,
    );
    when(
      () => metadataDatasource.fetch(metadata.id),
    ).thenAnswer((_) async => metadata);
    final protectedSecret =
        (await secrets.import(
                  words: protected.words.split(' '),
                  passphrase: passphrase,
                )
                as Ok<Secret, SecretFailure>)
            .value;
    expect(
      await secrets.retainCanonical(protectedSecret.id),
      isA<Ok<Secret, SecretFailure>>(),
    );
    final unsignedPsbt = buildUnsignedPsbt(descriptor: descriptor);

    final missing = await repository.signPsbt(
      unsignedPsbt,
      walletId: metadata.id,
      tryFinalize: false,
    );
    final wrong = await repository.signPsbt(
      unsignedPsbt,
      walletId: metadata.id,
      tryFinalize: false,
      passphrase: 'wrong passphrase',
    );
    final signed = await repository.signPsbt(
      unsignedPsbt,
      walletId: metadata.id,
      tryFinalize: false,
      passphrase: passphrase,
    );

    expect(_failureKind(missing), BitcoinSigningFailureKind.passphraseRequired);
    expect(_failureKind(wrong), BitcoinSigningFailureKind.passphraseMismatch);
    expect(signedFingerprints(_unwrapSigning(signed).psbt), {
      protected.fingerprint.toLowerCase(),
    });
  });

  test('maps wallet input validation failures to invalid PSBT', () async {
    final signer = _singleSignatureFixture(testMnemonics.first);
    final descriptor = twoPathDescriptor(
      signer.externalPublic,
      signer.internalPublic,
    );
    final metadata = _metadata(
      descriptor: descriptor,
      signers: [signer],
      localSignerCount: 1,
    );
    final wallet =
        WalletModel.publicBdk(
              id: metadata.id,
              descriptor: descriptor,
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final datasource = _MockBdkWalletDatasource();
    when(
      () => metadataDatasource.fetch(metadata.id),
    ).thenAnswer((_) async => metadata);
    when(
      () => datasource.validateWalletPsbtInputs(
        'psbt',
        wallet: wallet,
        frozenOutpoints: const {},
      ),
    ).thenThrow(const InvalidBitcoinPsbtException());
    final reviewRepository = BitcoinWalletRepository(
      walletMetadataDatasource: metadataDatasource,
      secrets: secrets,
      bdkWalletDatasource: datasource,
      frozenWalletUtxoDatasource: frozenWalletUtxoDatasource,
    );

    final result = await reviewRepository.reviewPsbt(
      'psbt',
      walletId: metadata.id,
      requireLocalOrigin: false,
    );

    expect(_failureKind(result), BitcoinSigningFailureKind.invalidPsbt);
  });

  test('maps malformed PSBT encoding to invalid PSBT', () async {
    final signer = _singleSignatureFixture(testMnemonics.first);
    final metadata = _metadata(
      descriptor: twoPathDescriptor(
        signer.externalPublic,
        signer.internalPublic,
      ),
      signers: [signer],
      localSignerCount: 0,
    );
    await stubWallet(metadata, const []);

    final result = await repository.reviewPsbt(
      'not-a-psbt',
      walletId: metadata.id,
      requireLocalOrigin: false,
    );

    expect(_failureKind(result), BitcoinSigningFailureKind.invalidPsbt);
  });

  test('does not report wallet storage failures as invalid PSBTs', () async {
    final signer = _singleSignatureFixture(testMnemonics.first);
    final descriptor = twoPathDescriptor(
      signer.externalPublic,
      signer.internalPublic,
    );
    final metadata = _metadata(
      descriptor: descriptor,
      signers: [signer],
      localSignerCount: 0,
    );
    final wallet =
        WalletModel.publicBdk(
              id: metadata.id,
              descriptor: descriptor,
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final datasource = _MockBdkWalletDatasource();
    when(
      () => metadataDatasource.fetch(metadata.id),
    ).thenAnswer((_) async => metadata);
    when(
      () => datasource.validateWalletPsbtInputs(
        'psbt',
        wallet: wallet,
        frozenOutpoints: const {},
      ),
    ).thenAnswer((_) async {});
    when(
      () => datasource.inspectPsbt(
        'psbt',
        wallet: wallet,
        walletFingerprints: any(named: 'walletFingerprints'),
      ),
    ).thenThrow(Exception('wallet database unavailable'));
    final reviewRepository = BitcoinWalletRepository(
      walletMetadataDatasource: metadataDatasource,
      secrets: secrets,
      bdkWalletDatasource: datasource,
      frozenWalletUtxoDatasource: frozenWalletUtxoDatasource,
    );

    final result = await reviewRepository.reviewPsbt(
      'psbt',
      walletId: metadata.id,
      requireLocalOrigin: false,
    );

    expect(_failureKind(result), BitcoinSigningFailureKind.unexpected);
  });

  test('maps mismatching external signer results to invalid PSBT', () async {
    final signer = _singleSignatureFixture(testMnemonics.first);
    final descriptor = twoPathDescriptor(
      signer.externalPublic,
      signer.internalPublic,
    );
    final metadata = _metadata(
      descriptor: descriptor,
      signers: [signer],
      localSignerCount: 0,
    );
    final datasource = _MockBdkWalletDatasource();
    when(
      () => metadataDatasource.fetch(metadata.id),
    ).thenAnswer((_) async => metadata);
    when(
      () => datasource.validateExternalPartialPsbt(
        currentPsbtBase64: 'current',
        signedPsbtBase64: 'unrelated',
      ),
    ).thenThrow(bdk.UnexpectedUnsignedTxPsbtException());
    when(
      () => datasource.verifyFinalTransaction(
        psbtBase64: 'current',
        transactionHex: 'unrelated',
      ),
    ).thenThrow(const FormatException());
    when(
      () => datasource.verifyFinalTransaction(
        psbtBase64: 'current',
        transactionHex: 'malformed',
      ),
    ).thenThrow(bdk.IoTransactionException());
    final signingRepository = BitcoinWalletRepository(
      walletMetadataDatasource: metadataDatasource,
      secrets: secrets,
      bdkWalletDatasource: datasource,
      frozenWalletUtxoDatasource: frozenWalletUtxoDatasource,
    );

    final results = [
      await signingRepository.combinePsbts(
        currentPsbt: 'current',
        signedPsbt: 'unrelated',
        walletId: metadata.id,
      ),
      await signingRepository.verifyFinalTransaction(
        psbt: 'current',
        transaction: 'unrelated',
      ),
      await signingRepository.verifyFinalTransaction(
        psbt: 'current',
        transaction: 'malformed',
      ),
    ];

    expect(
      results.map(_failureKind),
      everyElement(BitcoinSigningFailureKind.invalidPsbt),
    );
  });

  test('rejects a frozen input before adding a local signature', () async {
    final signer = _singleSignatureFixture(testMnemonics.first);
    final descriptor = twoPathDescriptor(
      signer.externalPublic,
      signer.internalPublic,
    );
    final metadata = _metadata(
      descriptor: descriptor,
      signers: [signer],
      localSignerCount: 1,
    );
    final wallet =
        WalletModel.publicBdk(
              id: metadata.id,
              descriptor: descriptor,
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final datasource = _MockBdkWalletDatasource();
    when(
      () => metadataDatasource.fetch(metadata.id),
    ).thenAnswer((_) async => metadata);
    when(() => frozenWalletUtxoDatasource.getAllFrozen()).thenAnswer(
      (_) async => const [(walletId: 'wallet', txId: 'funding', vout: 0)],
    );
    when(
      () => datasource.validateWalletPsbtInputs(
        'psbt',
        wallet: wallet,
        frozenOutpoints: const {'funding:0'},
      ),
    ).thenThrow(const BitcoinPsbtFrozenUtxoException());
    final signingRepository = BitcoinWalletRepository(
      walletMetadataDatasource: metadataDatasource,
      secrets: secrets,
      bdkWalletDatasource: datasource,
      frozenWalletUtxoDatasource: frozenWalletUtxoDatasource,
    );

    final result = await signingRepository.signPsbt(
      'psbt',
      walletId: metadata.id,
    );

    expect(_failureKind(result), BitcoinSigningFailureKind.frozenUtxo);
  });

  test('rejects a frozen input when combining signer PSBTs', () async {
    final signer = _singleSignatureFixture(testMnemonics.first);
    final descriptor = twoPathDescriptor(
      signer.externalPublic,
      signer.internalPublic,
    );
    final metadata = _metadata(
      descriptor: descriptor,
      signers: [signer],
      localSignerCount: 1,
    );
    final wallet =
        WalletModel.publicBdk(
              id: metadata.id,
              descriptor: descriptor,
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final datasource = _MockBdkWalletDatasource();
    when(
      () => metadataDatasource.fetch(metadata.id),
    ).thenAnswer((_) async => metadata);
    when(() => frozenWalletUtxoDatasource.getAllFrozen()).thenAnswer(
      (_) async => const [(walletId: 'wallet', txId: 'funding', vout: 0)],
    );
    when(
      () => datasource.validateExternalPartialPsbt(
        currentPsbtBase64: 'current',
        signedPsbtBase64: 'signed',
      ),
    ).thenReturn('combined');
    when(
      () => datasource.validateWalletPsbtInputs(
        'combined',
        wallet: wallet,
        frozenOutpoints: const {'funding:0'},
      ),
    ).thenThrow(const BitcoinPsbtFrozenUtxoException());
    final signingRepository = BitcoinWalletRepository(
      walletMetadataDatasource: metadataDatasource,
      secrets: secrets,
      bdkWalletDatasource: datasource,
      frozenWalletUtxoDatasource: frozenWalletUtxoDatasource,
    );

    final result = await signingRepository.combinePsbts(
      currentPsbt: 'current',
      signedPsbt: 'signed',
      walletId: metadata.id,
    );

    expect(_failureKind(result), BitcoinSigningFailureKind.frozenUtxo);
  });
}

T _unwrapSigning<T>(Result<T, BitcoinSigningFailure> result) =>
    switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError(
        'Unexpected failure: ${failure.kind}',
      ),
    };

BitcoinSigningFailureKind? _failureKind<T>(
  Result<T, BitcoinSigningFailure> result,
) => switch (result) {
  Ok() => null,
  Err(:final failure) => failure.kind,
};

WalletMetadataModel _multisigMetadata(
  List<_SignerFixture> signers, {
  required int localSignerCount,
}) {
  final externalDescriptor = sortedMultisigDescriptor(
    signers.map((signer) => signer.externalPublic).toList(),
  );
  final internalDescriptor = sortedMultisigDescriptor(
    signers.map((signer) => signer.internalPublic).toList(),
  );
  return _metadata(
    descriptor: twoPathDescriptor(externalDescriptor, internalDescriptor),
    signers: signers,
    localSignerCount: localSignerCount,
  );
}

WalletMetadataModel _metadata({
  required String descriptor,
  required List<_SignerFixture> signers,
  required int localSignerCount,
  String? derivationPath,
  String? descriptorPath,
}) => WalletMetadataModel(
  id: 'wallet',
  network: Network.bitcoinTestnet,
  signers: [
    for (final (index, signer) in signers.indexed)
      walletSignerModel(
        id: 'signer-$index',
        descriptorKeyId: 'key-$index',
        masterFingerprint: signer.fingerprint,
        xpubFingerprint: signer.fingerprint,
        xpub: signer.xpub,
        derivationPath:
            derivationPath ??
            (signers.length == 1 ? "m/84'/1'/0'" : "m/48'/1'/0'/2'"),
        descriptorPath:
            descriptorPath ??
            (signers.length == 1 ? standardSingleSignatureDescriptorPath : ''),
        signer: index < localSignerCount ? Signer.local : Signer.remote,
        signerDevice: null,
      ),
  ],
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  publicDescriptor: descriptor,
  isDefault: false,
);

_SignerFixture _singleSignatureFixture(
  String words, {
  int account = 0,
  ScriptType scriptType = ScriptType.bip84,
}) {
  final descriptors = scriptType == ScriptType.bip49
      ? nestedSegwitSingleSignatureDescriptors(words)
      : account == 0
      ? singleSignatureDescriptors(words)
      : singleSignatureDescriptorsAtAccount(words, account: account);
  return (
    externalPublic: descriptors.external,
    fingerprint: descriptors.fingerprint,
    internalPublic: descriptors.internal,
    words: words,
    passphrase: null,
    xpub: Bip32Derivation.getBip32Xpub(
      descriptors.xpub.split(']').last,
    ).convert(scriptType.getXpubType(Network.bitcoinTestnet)),
  );
}

_SignerFixture _multisigFixture(String words) {
  final keys = deriveSignerKeys(words);
  return (
    externalPublic: keys.externalPublic,
    fingerprint: keys.fingerprint,
    internalPublic: keys.internalPublic,
    words: words,
    passphrase: null,
    xpub: keys.xpub.split(']').last,
  );
}

_SignerFixture _bip48Fixture(String words, {String? passphrase}) {
  final root = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.test,
    mnemonic: bdk.Mnemonic.fromString(mnemonic: words),
    password: passphrase,
  );
  final account = root.derive(path: bdk.DerivationPath(path: "m/48'/1'/0'/2'"));
  final public = account.asPublic();
  return (
    externalPublic: '$public/0/*',
    fingerprint: public.masterFingerprint(),
    internalPublic: '$public/1/*',
    words: words,
    passphrase: passphrase,
    xpub: public.toString().split(']').last,
  );
}

_SignerFixture _miniscriptBip84Fixture(String words) {
  final root = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.test,
    mnemonic: bdk.Mnemonic.fromString(mnemonic: words),
    password: null,
  );
  final account = root.derive(path: bdk.DerivationPath(path: "m/84'/1'/0'"));
  final public = account.asPublic();
  return (
    externalPublic: '$public/0/*',
    fingerprint: public.masterFingerprint(),
    internalPublic: '$public/1/*',
    words: words,
    passphrase: null,
    xpub: public.toString().split(']').last,
  );
}

const _numsKey =
    '0250929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0';

Future<WalletMetadataModel> _migrateMetadata(
  WalletMetadataModel metadata,
  _SignerFixture signer,
) async {
  final verifier = SchemaVerifier(GeneratedHelper());
  final schema = await verifier.schemaAt(15);
  final legacy = v15.DatabaseAtV15(schema.newConnection());
  final key = metadata.signers.single.descriptorKeys.single;
  await legacy
      .into(legacy.walletMetadatas)
      .insert(
        v15.WalletMetadatasCompanion.insert(
          id: metadata.id,
          masterFingerprint: key.masterFingerprint,
          xpubFingerprint: key.xpubFingerprint,
          isEncryptedVaultTested: 0,
          isPhysicalBackupTested: 0,
          xpub: key.xpub,
          externalPublicDescriptor: signer.externalPublic,
          internalPublicDescriptor: signer.internalPublic,
          signer: 'local',
          isDefault: 1,
        ),
      );
  await legacy.close();
  final database = SqliteDatabase(schema.newConnection());
  try {
    await verifier.migrateAndValidate(database, 16);
    return (await WalletMetadataDatasource(
      sqlite: database,
    ).fetch(metadata.id))!;
  } finally {
    await database.close();
  }
}
