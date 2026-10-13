import 'dart:io';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/bitcoin_psbt_review_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/bitcoin_wallet_policy_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_signer_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_psbt_review_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_psbt_review_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bitcoin_base/bitcoin_base.dart' as bitcoin_base;
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import '../../bdk_wallet_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SignerDescriptorKeys> signers;
  late BdkWalletDatasource datasource;
  late Directory tempDirectory;

  setUpAll(() {
    signers = testMnemonics.map(deriveSignerKeys).toList();
  });

  setUp(() {
    datasource = BdkWalletDatasource();
    tempDirectory = Directory.systemTemp.createTempSync('bdk_taproot_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => call.method == 'getApplicationDocumentsDirectory'
              ? tempDirectory.path
              : null,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await tempDirectory.delete(recursive: true);
  });

  test('completes a Taproot key-path round trip', () {
    final publicDescriptor = _taprootKeyPathDescriptor(
      externalKey: signers.first.externalPublic,
      internalKey: signers.first.internalPublic,
    );
    final privateDescriptor = _taprootKeyPathDescriptor(
      externalKey: signers.first.externalPrivate,
      internalKey: signers.first.internalPrivate,
    );
    final unsigned = buildUnsignedPsbt(descriptor: publicDescriptor);

    final signed = datasource.signPsbtWithDescriptor(
      unsigned,
      descriptor: privateDescriptor,
      isTestnet: true,
      tryFinalize: false,
    );
    final finalized = datasource.finalizePsbt(signed.psbt);

    expect(signed.isFinalized, isFalse);
    expect(
      bdk.Psbt(psbtBase64: signed.psbt).input().single.tapKeySig,
      isNotNull,
    );
    expect(
      () => datasource.validateExternalPartialPsbt(
        currentPsbtBase64: unsigned,
        signedPsbtBase64: signed.psbt,
      ),
      returnsNormally,
    );
    expect(
      () => datasource.validateExternalPartialPsbt(
        currentPsbtBase64: unsigned,
        signedPsbtBase64: _replaceTaprootKeySignature(
          signed.psbt,
          (signature) => signature[0] ^= 1,
        ),
      ),
      throwsA(isA<InvalidBitcoinPsbtException>()),
    );
    final signedWithAll = datasource.signPsbtWithDescriptor(
      _withInputSighash(unsigned, bitcoin_base.BitcoinOpCodeConst.sighashAll),
      descriptor: privateDescriptor,
      isTestnet: true,
      tryFinalize: false,
    );
    expect(
      () => datasource.validateExternalPartialPsbt(
        currentPsbtBase64: unsigned,
        signedPsbtBase64: _withoutInputSighash(signedWithAll.psbt),
      ),
      returnsNormally,
    );
    expect(
      () => datasource.validateExternalPartialPsbt(
        currentPsbtBase64: _withInputSighash(
          unsigned,
          bitcoin_base.BitcoinOpCodeConst.sighashDefault,
        ),
        signedPsbtBase64: _withInputSighash(
          signedWithAll.psbt,
          bitcoin_base.BitcoinOpCodeConst.sighashDefault,
        ),
      ),
      throwsA(isA<BitcoinPsbtUnsupportedSighashException>()),
    );
    expect(finalized.isFinalized, isTrue);
    final transaction = hex.encode(
      bdk.Psbt(psbtBase64: finalized.psbt).extractTx().serialize(),
    );
    expect(
      () => datasource.verifyFinalTransaction(
        psbtBase64: unsigned,
        transactionHex: transaction,
      ),
      throwsFormatException,
    );
  });

  test('validates an explicitly selected key-path signature', () async {
    final publicDescriptor = _taprootKeyAndScriptDescriptor(
      externalInternalKey: signers[0].externalPublic,
      externalLeafKey: signers[1].externalPublic,
      internalInternalKey: signers[0].internalPublic,
      internalLeafKey: signers[1].internalPublic,
    );
    final parsed = BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: publicDescriptor,
      isTestnet: true,
    );
    final descriptorKeys = _descriptorKeyModels(parsed.keys);
    final wallet =
        WalletModel.publicBdk(
              id: 'taproot-key-path-selection',
              descriptor: publicDescriptor,
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final policy = BitcoinWalletPolicyMapper.toEntity(
      datasource.analyzePolicy(wallet: wallet, descriptorKeys: descriptorKeys),
    );
    final requirement = policy
        .pathSelectors(const BitcoinPolicySelection.empty())
        .first;
    final internalKeyIndex = requirement.options.indexWhere(
      (option) => _signatureKeyValues(option).contains('key-0'),
    );
    final selection = policy.select(
      current: const BitcoinPolicySelection.empty(),
      requirement: requirement,
      selectedIndices: {internalKeyIndex},
    );
    final path = policy.buildPath(selection);
    final recipient = await _fundStoredWallet(wallet);
    final unsigned = await datasource.buildPsbt(
      wallet: wallet,
      address: recipient,
      amountSat: 50000,
      networkFee: const NetworkFee.absolute(1000),
      policyPath: path,
      requiredDescriptorKeys: (
        external: descriptorKeys
            .where(
              (key) => path.requiredExternalKeys.any(
                (required) => required.value == key.id,
              ),
            )
            .toList(),
        internal: descriptorKeys
            .where(
              (key) => path.requiredInternalKeys.any(
                (required) => required.value == key.id,
              ),
            )
            .toList(),
      ),
    );
    final unsignedPsbt = bdk.Psbt(psbtBase64: unsigned);
    try {
      expect(unsignedPsbt.input().single.tapScripts, isEmpty);
    } finally {
      unsignedPsbt.dispose();
    }
    final signed = datasource.signPsbtWithDescriptor(
      unsigned,
      descriptor: _taprootKeyAndScriptDescriptor(
        externalInternalKey: signers[0].externalPrivate,
        externalLeafKey: signers[1].externalPublic,
        internalInternalKey: signers[0].internalPrivate,
        internalLeafKey: signers[1].internalPublic,
      ),
      isTestnet: true,
      tryFinalize: false,
    );
    final signedPsbt = bdk.Psbt(psbtBase64: signed.psbt);
    try {
      expect(signedPsbt.input().single.tapScripts, isEmpty);
    } finally {
      signedPsbt.dispose();
    }
    expect(
      () => datasource.validateExternalPartialPsbt(
        currentPsbtBase64: unsigned,
        signedPsbtBase64: signed.psbt,
      ),
      returnsNormally,
    );
  });

  test('keeps key-path signer status when Tapleaf metadata remains', () async {
    final descriptor = _taprootKeyPathDescriptor(
      externalKey: signers.first.externalPublic,
      internalKey: signers.first.internalPublic,
    );
    final wallet =
        WalletModel.publicBdk(
              id: 'taproot-key-path-review',
              descriptor: descriptor,
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final descriptorKeys = _descriptorKeyModels(
      BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: descriptor,
        isTestnet: true,
      ).keys,
    );
    final signed = datasource.signPsbtWithDescriptor(
      buildUnsignedPsbt(descriptor: descriptor),
      descriptor: _taprootKeyPathDescriptor(
        externalKey: signers.first.externalPrivate,
        internalKey: signers.first.internalPrivate,
      ),
      isTestnet: true,
      tryFinalize: false,
    );
    final inspected = await datasource.inspectPsbt(
      signed.psbt,
      wallet: wallet,
      walletFingerprints: {signers.first.fingerprint},
    );
    final input = inspected.inputs.single;
    final withRetainedLeaf = BitcoinPsbtReviewModel(
      transactionId: inspected.transactionId,
      inputs: [
        (
          amountSat: input.amountSat,
          keychain: input.keychain,
          originKeySources: input.originKeySources,
          satisfiedPreimageKeys: input.satisfiedPreimageKeys,
          signedKeySources: input.signedKeySources,
          tapLeafHashes: const {'retained-leaf'},
          outpoint: input.outpoint,
          sequence: input.sequence,
        ),
      ],
      outputs: inspected.outputs,
      feeSat: inspected.feeSat,
      estimatedTransactionVsize: inspected.estimatedTransactionVsize,
      isFinalized: inspected.isFinalized,
      lockTime: inspected.lockTime,
      version: inspected.version,
    );

    final review = BitcoinPsbtReviewMapper.toEntity(
      withRetainedLeaf,
      descriptorKeys: descriptorKeys,
      localSignerIds: const {},
    );

    expect(review.inputs.single.signedDescriptorKeyIds, {'key-0'});
  });

  test('accepts a Taproot input with only its non-witness UTXO', () async {
    final descriptor = _taprootKeyPathDescriptor(
      externalKey: signers.first.externalPublic,
      internalKey: signers.first.internalPublic,
    );
    final unsigned = buildUnsignedPsbt(descriptor: descriptor);
    final bdkPsbt = bdk.Psbt(psbtBase64: unsigned);
    final script = bdk.Script(
      rawOutputScript: bdkPsbt
          .input()
          .single
          .witnessUtxo!
          .scriptPubkey
          .toBytes(),
    );
    bdkPsbt.dispose();
    final previousTransaction = bitcoin_base.BtcTransaction.deserialize(
      fundingTransaction(script).serialize(),
    );
    final psbt = bitcoin_base.Psbt.fromBase64(unsigned);
    psbt.input.removeInputKeys(0, [
      bitcoin_base.PsbtInputTypes.nonWitnessUTXO,
      bitcoin_base.PsbtInputTypes.witnessUTXO,
      bitcoin_base.PsbtInputTypes.sighashType,
    ]);
    psbt.input.updateInputs(0, [
      bitcoin_base.PsbtInputNonWitnessUtxo(previousTransaction),
      bitcoin_base.PsbtInputSigHash(
        bitcoin_base.BitcoinOpCodeConst.sighashDefault,
      ),
    ]);

    await expectLater(
      datasource.inspectPsbt(
        psbt.toBase64(),
        wallet:
            WalletModel.publicBdk(
                  id: 'taproot-non-witness-utxo',
                  descriptor: descriptor,
                  isTestnet: true,
                )
                as PublicBdkWalletModel,
        walletFingerprints: {signers.first.fingerprint},
      ),
      completes,
    );
  });

  test('rejects mixed Taproot key-path and script-path inputs', () {
    final publicDescriptor = _taprootKeyAndScriptDescriptor(
      externalInternalKey: signers[0].externalPublic,
      externalLeafKey: signers[1].externalPublic,
      internalInternalKey: signers[0].internalPublic,
      internalLeafKey: signers[1].internalPublic,
    );
    final psbt = bitcoin_base.Psbt.fromBase64(
      buildUnsignedPsbt(
        descriptor: publicDescriptor,
        amountSat: 150000,
        inputCount: 2,
      ),
    );
    _retainTaprootSpendMode(psbt, index: 0, keyPath: true);
    _retainTaprootSpendMode(psbt, index: 1, keyPath: false);
    expect(
      () => datasource.signPsbtWithDescriptor(
        psbt.toBase64(),
        descriptor: _taprootKeyAndScriptDescriptor(
          externalInternalKey: signers[0].externalPrivate,
          externalLeafKey: signers[1].externalPublic,
          internalInternalKey: signers[0].internalPrivate,
          internalLeafKey: signers[1].internalPublic,
        ),
        isTestnet: true,
      ),
      throwsA(isA<BitcoinPsbtUnsupportedSpendModeException>()),
    );
  });

  test('excludes a provably unspendable internal key from signers', () {
    final descriptor = _descriptorWithUnspendableInternalKey(signers);
    final parsed = BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      isTestnet: true,
    );
    final descriptorKeys = _descriptorKeyModels(parsed.keys);
    final wallet =
        WalletModel.publicBdk(
              id: 'unspendable-internal-key',
              descriptor: descriptor,
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final policy = BitcoinWalletPolicyMapper.toEntity(
      datasource.analyzePolicy(wallet: wallet, descriptorKeys: descriptorKeys),
    );

    expect(parsed.keys, hasLength(signers.length));
    expect(parsed.policyKeys, hasLength(signers.length + 1));
    expect(parsed.unspendablePolicyKeyIdentifiers, isNotEmpty);
    expect(_signatureKeyValues(policy.external.root), {
      for (var index = 0; index < signers.length; index++) 'key-$index',
    });
  });

  test('omits only a fixed BIP341 NUMS key origin from built PSBTs', () async {
    await _withTemporaryBdkDirectory('bdk_taproot_nums_', () async {
      final fixedNumsWallet =
          WalletModel.publicBdk(
                id: 'fixed-nums-origin',
                descriptor: _taprootScriptDescriptor(
                  externalKeys: signers
                      .map((signer) => signer.externalPublic)
                      .toList(),
                  internalKeys: signers
                      .map((signer) => signer.internalPublic)
                      .toList(),
                ),
                isTestnet: true,
              )
              as PublicBdkWalletModel;
      final fixedNumsRecipient = await _fundStoredWallet(fixedNumsWallet);
      final fixedNumsPsbt = bdk.Psbt(
        psbtBase64: await datasource.buildPsbt(
          wallet: fixedNumsWallet,
          address: fixedNumsRecipient,
          amountSat: 50000,
          networkFee: const NetworkFee.absolute(1000),
        ),
      );
      try {
        final origins = fixedNumsPsbt.input().single.tapKeyOrigins;
        expect(origins, isNot(contains(_numsKey.substring(2))));
        expect(origins, hasLength(signers.length));
        expect(
          origins.values.every((origin) => origin.tapLeafHashes.isNotEmpty),
          isTrue,
        );
        for (final output in fixedNumsPsbt.output()) {
          expect(output.tapKeyOrigins, isNot(contains(_numsKey.substring(2))));
          expect(output.tapKeyOrigins, hasLength(signers.length));
        }

        final unnormalizedPsbt = bitcoin_base.Psbt.fromBase64(
          fixedNumsPsbt.serialize(),
        );
        unnormalizedPsbt.input.updateInputs(0, [
          bitcoin_base.PsbtInputTaprootKeyBip32DerivationPath(
            xOnlyPubKey: hex.decode(_numsKey.substring(2)),
            leavesHashes: const [],
            fingerprint: const [0, 0, 0, 0],
            indexes: const [],
          ),
        ]);
        final signedPsbt = bdk.Psbt(
          psbtBase64: datasource
              .signPsbtWithDescriptor(
                unnormalizedPsbt.toBase64(),
                descriptor: _privateTaprootScriptDescriptor(signers, 0),
                isTestnet: true,
                tryFinalize: false,
              )
              .psbt,
        );
        try {
          expect(
            signedPsbt.input().single.tapKeyOrigins,
            isNot(contains(_numsKey.substring(2))),
          );
          for (final output in signedPsbt.output()) {
            expect(
              output.tapKeyOrigins,
              isNot(contains(_numsKey.substring(2))),
            );
          }
        } finally {
          signedPsbt.dispose();
        }
      } finally {
        fixedNumsPsbt.dispose();
      }

      final numsXpubWallet =
          WalletModel.publicBdk(
                id: 'nums-xpub-origin',
                descriptor: _descriptorWithUnspendableInternalKey(signers),
                isTestnet: true,
              )
              as PublicBdkWalletModel;
      final numsXpubRecipient = await _fundStoredWallet(numsXpubWallet);
      final numsXpubPsbt = bdk.Psbt(
        psbtBase64: await datasource.buildPsbt(
          wallet: numsXpubWallet,
          address: numsXpubRecipient,
          amountSat: 50000,
          networkFee: const NetworkFee.absolute(1000),
        ),
      );
      try {
        final origins = numsXpubPsbt.input().single.tapKeyOrigins.values;
        expect(
          origins.where((origin) => origin.tapLeafHashes.isEmpty),
          hasLength(1),
        );
        expect(
          origins.where((origin) => origin.tapLeafHashes.isNotEmpty),
          hasLength(signers.length),
        );
        for (final output in numsXpubPsbt.output()) {
          expect(
            output.tapKeyOrigins.values.where(
              (origin) => origin.tapLeafHashes.isEmpty,
            ),
            hasLength(1),
          );
        }
      } finally {
        numsXpubPsbt.dispose();
      }
    });
  });

  test('rejects ambiguous unspendable internal-key metadata', () {
    final numsXpub = _unspendableInternalXpub();
    final fingerprint = signers.first.fingerprint;
    final descriptor = twoPathDescriptor(
      'tr([$fingerprint]$numsXpub/0/*,pk(${signers.first.externalPublic}))',
      'tr([$fingerprint]$numsXpub/1/*,pk(${signers.first.internalPublic}))',
    );

    expect(
      () => BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: descriptor,
        isTestnet: true,
      ),
      throwsFormatException,
    );
  });

  test('rejects an unspendable internal xpub reused in a script', () {
    final numsXpub = _unspendableInternalXpub();
    final descriptor = twoPathDescriptor(
      'tr([00000000]$numsXpub/0/*,pk([00000000]$numsXpub/0/*))',
      'tr([00000000]$numsXpub/1/*,pk([00000000]$numsXpub/1/*))',
    );

    expect(
      () => BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: descriptor,
        isTestnet: true,
      ),
      throwsFormatException,
    );
  });

  test('requires a choice between separate Taproot leaves', () {
    final descriptor = twoPathDescriptor(
      'tr($_numsKey,{pk(${signers[0].externalPublic}),pk(${signers[1].externalPublic})})',
      'tr($_numsKey,{pk(${signers[0].internalPublic}),pk(${signers[1].internalPublic})})',
    );
    final parsed = BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      isTestnet: true,
    );
    final descriptorKeys = _descriptorKeyModels(parsed.keys);
    final policy = BitcoinWalletPolicyMapper.toEntity(
      datasource.analyzePolicy(
        wallet:
            WalletModel.publicBdk(
                  id: 'taproot-leaves',
                  descriptor: descriptor,
                  isTestnet: true,
                )
                as PublicBdkWalletModel,
        descriptorKeys: descriptorKeys,
      ),
    );

    final requirement = policy
        .pathSelectors(const BitcoinPolicySelection.empty())
        .single;
    final selection = policy.select(
      current: const BitcoinPolicySelection.empty(),
      requirement: requirement,
      selectedIndices: const {0},
    );
    final path = policy.buildPath(selection);

    expect(requirement.options, hasLength(2));
    expect(path.requiredExternalKeys.single.value, 'key-0');
    expect(path.requiredInternalKeys.single.value, 'key-0');
  });

  test('preserves the BDK root path for a single Taproot leaf', () async {
    await _withTemporaryBdkDirectory('bdk_taproot_single_leaf_', () async {
      final descriptor = twoPathDescriptor(
        'tr($_numsKey,pk(${signers.first.externalPublic}))',
        'tr($_numsKey,pk(${signers.first.internalPublic}))',
      );
      final parsed = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: descriptor,
        isTestnet: true,
      );
      final descriptorKeys = _descriptorKeyModels(parsed.keys);
      final wallet =
          WalletModel.publicBdk(
                id: 'taproot-single-leaf',
                descriptor: descriptor,
                isTestnet: true,
              )
              as PublicBdkWalletModel;
      final policy = BitcoinWalletPolicyMapper.toEntity(
        datasource.analyzePolicy(
          wallet: wallet,
          descriptorKeys: descriptorKeys,
        ),
      );
      final path = policy.buildPath(const BitcoinPolicySelection.empty());
      final recipient = await _fundStoredWallet(wallet);

      expect(path.external.values.single, [1]);
      expect(path.internal.values.single, [1]);
      await expectLater(
        datasource.buildPsbt(
          wallet: wallet,
          address: recipient,
          amountSat: 50000,
          networkFee: const NetworkFee.absolute(1000),
          policyPath: path,
          requiredDescriptorKeys: (
            external: descriptorKeys,
            internal: descriptorKeys,
          ),
        ),
        completes,
      );
    });
  });

  test('removes unselected keys from a selected Taproot leaf', () async {
    await _withTemporaryBdkDirectory('bdk_taproot_selected_keys_', () async {
      final descriptor = twoPathDescriptor(
        'tr($_numsKey,{pk(${signers[0].externalPublic}),pk(${signers[1].externalPublic})})',
        'tr($_numsKey,{pk(${signers[0].internalPublic}),pk(${signers[1].internalPublic})})',
      );
      final parsed = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: descriptor,
        isTestnet: true,
      );
      final descriptorKeys = _descriptorKeyModels(parsed.keys);
      final wallet =
          WalletModel.publicBdk(
                id: 'taproot-selected-keys',
                descriptor: descriptor,
                isTestnet: true,
              )
              as PublicBdkWalletModel;
      final policy = BitcoinWalletPolicyMapper.toEntity(
        datasource.analyzePolicy(
          wallet: wallet,
          descriptorKeys: descriptorKeys,
        ),
      );
      final requirement = policy
          .pathSelectors(const BitcoinPolicySelection.empty())
          .single;
      final selection = policy.select(
        current: const BitcoinPolicySelection.empty(),
        requirement: requirement,
        selectedIndices: const {0},
      );
      final path = policy.buildPath(selection);
      final requiredKeyIds = path.requiredExternalKeys
          .map((key) => key.value)
          .toSet();
      final requiredInternalKeyIds = path.requiredInternalKeys
          .map((key) => key.value)
          .toSet();
      final recipient = await _fundStoredWallet(wallet);
      final psbt = bdk.Psbt(
        psbtBase64: await datasource.buildPsbt(
          wallet: wallet,
          address: recipient,
          amountSat: 50000,
          networkFee: const NetworkFee.absolute(1000),
          policyPath: path,
          requiredDescriptorKeys: (
            external: descriptorKeys
                .where((key) => requiredKeyIds.contains(key.id))
                .toList(),
            internal: descriptorKeys
                .where((key) => requiredInternalKeyIds.contains(key.id))
                .toList(),
          ),
        ),
      );
      try {
        final origins = psbt.input().single.tapKeyOrigins.values;
        expect(origins, hasLength(1));
        expect(origins.single.tapLeafHashes, hasLength(1));
      } finally {
        psbt.dispose();
      }
    });
  });

  test('builds and satisfies a selected Taproot hashlock path', () async {
    await _withTemporaryBdkDirectory('bdk_taproot_path_', () async {
      final descriptor = _taprootConditionalDescriptor(
        externalKeys: signers.map((signer) => signer.externalPublic).toList(),
        internalKeys: signers.map((signer) => signer.internalPublic).toList(),
      );
      final wallet =
          WalletModel.publicBdk(
                id: 'taproot-conditions',
                descriptor: descriptor,
                isTestnet: true,
              )
              as PublicBdkWalletModel;
      final parsed = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: descriptor,
        isTestnet: true,
      );
      final descriptorKeys = _descriptorKeyModels(parsed.keys);
      final policy = BitcoinWalletPolicyMapper.toEntity(
        datasource.analyzePolicy(
          wallet: wallet,
          descriptorKeys: descriptorKeys,
        ),
      );
      final selection = _selectOptionContaining<BitcoinHashlockPolicyNode>(
        policy,
      );
      final recipientAddress = await _fundStoredWallet(wallet);

      final policyPath = policy.buildPath(selection);
      final unsigned = await datasource.buildPsbt(
        wallet: wallet,
        address: recipientAddress,
        amountSat: 50000,
        networkFee: const NetworkFee.absolute(1000),
        policyPath: policyPath,
        requiredDescriptorKeys: (
          external: descriptorKeys
              .where(
                (key) => policyPath.requiredExternalKeys.any(
                  (policyKey) => policyKey.matches(key.toEntity()),
                ),
              )
              .toList(),
          internal: descriptorKeys
              .where(
                (key) => policyPath.requiredInternalKeys.any(
                  (policyKey) => policyKey.matches(key.toEntity()),
                ),
              )
              .toList(),
        ),
      );
      final withPreimage = datasource.applyPolicyPreimages(unsigned, [
        BitcoinPolicyPreimage(
          type: BitcoinHashlockType.sha256,
          hash: _preimageHash,
          preimageHex: _preimage,
        ),
      ]);
      final review = BitcoinPsbtReviewMapper.toEntity(
        await datasource.inspectPsbt(
          unsigned,
          wallet: wallet,
          walletFingerprints: signers
              .map((signer) => signer.fingerprint)
              .toSet(),
        ),
        descriptorKeys: descriptorKeys,
        localSignerIds: const {'signer-0'},
      );

      final psbt = bdk.Psbt(psbtBase64: withPreimage);
      try {
        expect(psbt.input().single.tapScripts, hasLength(1));
        expect(psbt.extractTx().input().single.sequence, 10);
      } finally {
        psbt.dispose();
      }
      expect(policy.hasHashlock, isTrue);
      expect(policy.hasTimelock, isTrue);
      expect(review.inputs.single.hasLocalSignerOrigin, isFalse);
      expect(
        datasource
            .signPsbtWithDescriptor(
              withPreimage,
              descriptor: _privateTaprootConditionalDescriptor(signers),
              isTestnet: true,
            )
            .isFinalized,
        isTrue,
      );
    });
  });

  test('validates signer status and both Taproot signing orders', () async {
    final publicDescriptor = _taprootScriptDescriptor(
      externalKeys: signers.map((signer) => signer.externalPublic).toList(),
      internalKeys: signers.map((signer) => signer.internalPublic).toList(),
    );
    final wallet =
        WalletModel.publicBdk(
              id: 'taproot-threshold',
              descriptor: publicDescriptor,
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final descriptorKeys = _descriptorKeyModels(
      BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: publicDescriptor,
        isTestnet: true,
      ).keys,
    );
    final policy = BitcoinWalletPolicyMapper.toEntity(
      datasource.analyzePolicy(wallet: wallet, descriptorKeys: descriptorKeys),
    );
    final selection = _selectThresholdPath(policy);
    final unsigned = buildUnsignedPsbt(
      descriptor: publicDescriptor,
      policyPath: policy.buildPath(selection),
    );

    expect(policy.requiresPath, isFalse);
    for (final order in const [
      [0, 1],
      [1, 0],
    ]) {
      var current = unsigned;
      final expectedSignedKeyIds = <String>{};
      for (final signerIndex in order) {
        final signed = datasource.signPsbtWithDescriptor(
          current,
          descriptor: _privateTaprootScriptDescriptor(signers, signerIndex),
          isTestnet: true,
          tryFinalize: false,
        );
        expect(
          () => datasource.validateExternalPartialPsbt(
            currentPsbtBase64: current,
            signedPsbtBase64: signed.psbt,
          ),
          returnsNormally,
        );
        current = signed.psbt;
        expectedSignedKeyIds.add('key-$signerIndex');
        final review = BitcoinPsbtReviewMapper.toEntity(
          await datasource.inspectPsbt(
            current,
            wallet: wallet,
            walletFingerprints: signers
                .map((signer) => signer.fingerprint)
                .toSet(),
          ),
          descriptorKeys: descriptorKeys,
          localSignerIds: const {},
        );
        expect(
          review.inputs.single.signedDescriptorKeyIds,
          expectedSignedKeyIds,
        );
      }
      expect(datasource.finalizePsbt(current).isFinalized, isTrue);
    }
  });

  test('rejects a Taproot signature not authorized by the current PSBT', () {
    final descriptor = _taprootScriptDescriptor(
      externalKeys: signers.map((signer) => signer.externalPublic).toList(),
      internalKeys: signers.map((signer) => signer.internalPublic).toList(),
    );
    final wallet =
        WalletModel.publicBdk(
              id: 'taproot-returned-origin',
              descriptor: descriptor,
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final descriptorKeys = _descriptorKeyModels(
      BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: descriptor,
        isTestnet: true,
      ).keys,
    );
    final policy = BitcoinWalletPolicyMapper.toEntity(
      datasource.analyzePolicy(wallet: wallet, descriptorKeys: descriptorKeys),
    );
    final unsigned = buildUnsignedPsbt(
      descriptor: descriptor,
      policyPath: policy.buildPath(_selectThresholdPath(policy)),
    );
    final current = bitcoin_base.Psbt.fromBase64(unsigned);
    current.input.replaceInput(
      0,
      current.input.entries.single.where((entry) {
        if (entry
            case final bitcoin_base.PsbtInputTaprootKeyBip32DerivationPath
                origin) {
          return hex.encode(origin.fingerprint) != signers[2].fingerprint;
        }
        return true;
      }).toList(),
    );
    final returned = datasource.signPsbtWithDescriptor(
      unsigned,
      descriptor: _privateTaprootScriptDescriptor(signers, 2),
      isTestnet: true,
      tryFinalize: false,
    );

    expect(
      () => datasource.validateExternalPartialPsbt(
        currentPsbtBase64: current.toBase64(),
        signedPsbtBase64: returned.psbt,
      ),
      throwsA(isA<InvalidBitcoinPsbtException>()),
    );
  });

  test('rejects forged and unsupported Taproot signatures', () {
    final descriptor = _taprootScriptDescriptor(
      externalKeys: signers.map((signer) => signer.externalPublic).toList(),
      internalKeys: signers.map((signer) => signer.internalPublic).toList(),
    );
    final unsigned = buildUnsignedPsbt(descriptor: descriptor);
    final signed = datasource.signPsbtWithDescriptor(
      unsigned,
      descriptor: _privateTaprootScriptDescriptor(signers, 0),
      isTestnet: true,
      tryFinalize: false,
    );

    expect(
      () => datasource.validateExternalPartialPsbt(
        currentPsbtBase64: unsigned,
        signedPsbtBase64: _replaceTaprootSignature(
          signed.psbt,
          (signature) => signature[0] ^= 1,
        ),
      ),
      throwsA(isA<InvalidBitcoinPsbtException>()),
    );
    expect(
      () => datasource.validateExternalPartialPsbt(
        currentPsbtBase64: unsigned,
        signedPsbtBase64: _replaceTaprootSignature(
          signed.psbt,
          (signature) =>
              signature.add(bitcoin_base.BitcoinOpCodeConst.sighashNone),
        ),
      ),
      throwsA(isA<BitcoinPsbtUnsupportedSighashException>()),
    );
  });

  test('rejects Tapleaf control blocks for another output key', () async {
    final descriptor = _taprootScriptDescriptor(
      externalKeys: signers.map((signer) => signer.externalPublic).toList(),
      internalKeys: signers.map((signer) => signer.internalPublic).toList(),
    );
    final unsigned = buildUnsignedPsbt(descriptor: descriptor);
    final signed = datasource.signPsbtWithDescriptor(
      unsigned,
      descriptor: _privateTaprootScriptDescriptor(signers, 0),
      isTestnet: true,
      tryFinalize: false,
    );
    final wallet =
        WalletModel.publicBdk(
              id: 'taproot-control-block',
              descriptor: descriptor,
              isTestnet: true,
            )
            as PublicBdkWalletModel;

    await expectLater(
      datasource.inspectPsbt(
        _mutateTaprootControlBlock(unsigned),
        wallet: wallet,
        walletFingerprints: signers.map((signer) => signer.fingerprint).toSet(),
      ),
      throwsA(isA<InvalidBitcoinPsbtException>()),
    );

    expect(
      () => datasource.validateExternalPartialPsbt(
        currentPsbtBase64: _mutateTaprootControlBlock(unsigned),
        signedPsbtBase64: _mutateTaprootControlBlock(signed.psbt),
      ),
      throwsA(isA<InvalidBitcoinPsbtException>()),
    );
  });

  test('rejects key-path signatures for a selected script path', () {
    final publicDescriptor = _taprootKeyAndScriptDescriptor(
      externalInternalKey: signers[0].externalPublic,
      externalLeafKey: signers[1].externalPublic,
      internalInternalKey: signers[0].internalPublic,
      internalLeafKey: signers[1].internalPublic,
    );
    final parsed = BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: publicDescriptor,
      isTestnet: true,
    );
    final policy = BitcoinWalletPolicyMapper.toEntity(
      datasource.analyzePolicy(
        wallet:
            WalletModel.publicBdk(
                  id: 'script-path-intent',
                  descriptor: publicDescriptor,
                  isTestnet: true,
                )
                as PublicBdkWalletModel,
        descriptorKeys: _descriptorKeyModels(parsed.keys),
      ),
    );
    final requirement = policy
        .pathSelectors(const BitcoinPolicySelection.empty())
        .single;
    final scriptPathIndex = requirement.options.indexWhere(
      (option) => _signatureKeyValues(option).contains('key-1'),
    );
    final selection = policy.select(
      current: const BitcoinPolicySelection.empty(),
      requirement: requirement,
      selectedIndices: {scriptPathIndex},
    );
    final unfilteredUnsigned = buildUnsignedPsbt(
      descriptor: publicDescriptor,
      policyPath: policy.buildPath(selection),
    );
    final signedPsbt = bdk.Psbt(psbtBase64: unfilteredUnsigned);
    final signingWallet = BdkFacade.createEphemeralDescriptorWallet(
      descriptor: _taprootKeyAndScriptDescriptor(
        externalInternalKey: signers[0].externalPrivate,
        externalLeafKey: signers[1].externalPublic,
        internalInternalKey: signers[0].internalPrivate,
        internalLeafKey: signers[1].internalPublic,
      ),
      isTestnet: true,
    );
    try {
      signingWallet.sign(
        psbt: signedPsbt,
        signOptions: bdk.SignOptions(
          trustWitnessUtxo: true,
          assumeHeight: null,
          allowAllSighashes: false,
          tryFinalize: false,
          signWithTapInternalKey: true,
          allowGrinding: true,
        ),
      );
      expect(signedPsbt.input().single.tapKeySig, isNotNull);
      final currentPsbt = bitcoin_base.Psbt.fromBase64(unfilteredUnsigned);
      _retainTaprootSpendMode(currentPsbt, index: 0, keyPath: false);
      final returnedPsbt = bitcoin_base.Psbt.fromBase64(currentPsbt.toBase64());
      final keySignature = bitcoin_base.Psbt.fromBase64(signedPsbt.serialize())
          .input
          .getInputs<bitcoin_base.PsbtInputTaprootKeySpendSignature>(
            0,
            bitcoin_base.PsbtInputTypes.taprootKeySpentSignature,
          )!
          .single;
      returnedPsbt.input.updateInputs(0, [keySignature]);
      expect(
        () => datasource.validateExternalPartialPsbt(
          currentPsbtBase64: currentPsbt.toBase64(),
          signedPsbtBase64: returnedPsbt.toBase64(),
        ),
        throwsA(isA<InvalidBitcoinPsbtException>()),
      );
    } finally {
      signingWallet.dispose();
      signedPsbt.dispose();
    }
  });

  test('rejects unsupported MuSig2 PSBT fields', () {
    final descriptor = _taprootKeyPathDescriptor(
      externalKey: signers.first.externalPublic,
      internalKey: signers.first.internalPublic,
    );
    final psbt = bitcoin_base.Psbt.fromBase64(
      buildUnsignedPsbt(descriptor: descriptor),
    );
    final publicKey = bitcoin_base.ECPublic.fromHex(_numsKey);
    psbt.input.updateInputs(0, [
      bitcoin_base.PsbtInputMuSig2ParticipantPublicKeys(
        aggregatePubKey: publicKey,
        pubKeys: [publicKey],
      ),
    ]);

    expect(
      () => datasource.finalizePsbt(psbt.toBase64()),
      throwsA(isA<InvalidBitcoinPsbtException>()),
    );
  });
}

void _retainTaprootSpendMode(
  bitcoin_base.Psbt psbt, {
  required int index,
  required bool keyPath,
}) {
  final entries = psbt.input.entries[index].where((entry) {
    if (entry.type == bitcoin_base.PsbtInputTypes.taprootLeafScript) {
      return !keyPath;
    }
    if (entry
        case final bitcoin_base.PsbtInputTaprootKeyBip32DerivationPath
            derivation) {
      return keyPath
          ? derivation.leavesHashes.isEmpty
          : derivation.leavesHashes.isNotEmpty;
    }
    return true;
  }).toList();
  psbt.input.replaceInput(index, entries);
}

Future<void> _withTemporaryBdkDirectory(
  String prefix,
  Future<void> Function() body,
) async {
  final directory = await Directory.systemTemp.createTemp(prefix);
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return directory.path;
        }
        return null;
      });
  try {
    await body();
  } finally {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  }
}

Future<String> _fundStoredWallet(PublicBdkWalletModel wallet) async {
  final bdkWallet = await BdkFacade.createWallet(wallet);
  try {
    final fundingAddress = bdkWallet.peekAddress(
      keychain: bdk.KeychainKind.external_,
      index: 0,
    );
    final recipientAddress = bdkWallet.peekAddress(
      keychain: bdk.KeychainKind.external_,
      index: 1,
    );
    bdkWallet.applyUnconfirmedTxs(
      unconfirmedTxs: [
        bdk.UnconfirmedTx(
          tx: fundingTransaction(fundingAddress.address.scriptPubkey()),
          lastSeen: 1,
        ),
      ],
    );
    await BdkFacade.saveWallet(bdkWallet, wallet.hexId);
    return recipientAddress.address.toString();
  } finally {
    bdkWallet.dispose();
  }
}

const _numsKey =
    '0250929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0';
const _preimage =
    '0000000000000000000000000000000000000000000000000000000000000001';
final _preimageHash = sha256.convert(hex.decode(_preimage)).toString();

String _unspendableInternalXpub() {
  final network = bip32.NetworkType(
    wif: 0xef,
    bip32: bip32.Bip32Type(public: 0x043587cf, private: 0x04358394),
  );
  final key = bip32.Bip32Keys.fromPublicKey(
    Uint8List.fromList(hex.decode(_numsKey)),
    Uint8List.fromList(List<int>.generate(32, (index) => index)),
    network: network,
  );
  return key.toBase58();
}

String _descriptorWithUnspendableInternalKey(
  List<SignerDescriptorKeys> signers,
) {
  final numsXpub = _unspendableInternalXpub();
  return twoPathDescriptor(
    'tr([00000000]$numsXpub/0/*,multi_a(2,${signers.map((signer) => signer.externalPublic).join(',')}))',
    'tr([00000000]$numsXpub/1/*,multi_a(2,${signers.map((signer) => signer.internalPublic).join(',')}))',
  );
}

List<WalletDescriptorKeyModel> _descriptorKeyModels(
  List<BdkDescriptorKey> keys,
) => [
  for (final (index, key) in keys.indexed)
    WalletDescriptorKeyModel(
      id: 'key-$index',
      signerId: 'signer-$index',
      masterFingerprint: key.masterFingerprint,
      xpubFingerprint: key.xpubFingerprint,
      xpub: key.xpub,
      derivationPath: key.derivationPath,
    ),
];

Set<String> _signatureKeyValues(BitcoinPolicyNode node) => switch (node) {
  BitcoinSignaturePolicyNode(:final key) => {key.value},
  BitcoinThresholdPolicyNode(:final children) => {
    for (final child in children) ..._signatureKeyValues(child),
  },
  _ => const {},
};

String _taprootKeyPathDescriptor({
  required String externalKey,
  required String internalKey,
}) => twoPathDescriptor('tr($externalKey)', 'tr($internalKey)');

String _taprootKeyAndScriptDescriptor({
  required String externalInternalKey,
  required String externalLeafKey,
  required String internalInternalKey,
  required String internalLeafKey,
}) => twoPathDescriptor(
  'tr($externalInternalKey,pk($externalLeafKey))',
  'tr($internalInternalKey,pk($internalLeafKey))',
);

String _taprootScriptDescriptor({
  required List<String> externalKeys,
  required List<String> internalKeys,
}) => twoPathDescriptor(
  'tr($_numsKey,multi_a(2,${externalKeys.join(',')}))',
  'tr($_numsKey,multi_a(2,${internalKeys.join(',')}))',
);

String _privateTaprootScriptDescriptor(
  List<SignerDescriptorKeys> signers,
  int privateSignerIndex,
) => _taprootScriptDescriptor(
  externalKeys: [
    for (final (index, signer) in signers.indexed)
      index == privateSignerIndex
          ? signer.externalPrivate
          : signer.externalPublic,
  ],
  internalKeys: [
    for (final (index, signer) in signers.indexed)
      index == privateSignerIndex
          ? signer.internalPrivate
          : signer.internalPublic,
  ],
);

String _taprootConditionalDescriptor({
  required List<String> externalKeys,
  required List<String> internalKeys,
}) => twoPathDescriptor(
  'tr($_numsKey,{multi_a(2,${externalKeys.take(2).join(',')}),'
      'and_v(v:pk(${externalKeys.last}),'
      'and_v(v:older(10),sha256($_preimageHash)))})',
  'tr($_numsKey,{multi_a(2,${internalKeys.take(2).join(',')}),'
      'and_v(v:pk(${internalKeys.last}),'
      'and_v(v:older(10),sha256($_preimageHash)))})',
);

String _privateTaprootConditionalDescriptor(
  List<SignerDescriptorKeys> signers,
) => _taprootConditionalDescriptor(
  externalKeys: [
    signers[0].externalPublic,
    signers[1].externalPublic,
    signers.last.externalPrivate,
  ],
  internalKeys: [
    signers[0].internalPublic,
    signers[1].internalPublic,
    signers.last.internalPrivate,
  ],
);

BitcoinPolicySelection _selectThresholdPath(BitcoinWalletPolicy policy) {
  var selection = const BitcoinPolicySelection.empty();
  while (policy.pathRequirements(selection).isNotEmpty) {
    final requirement = policy.pathSelectors(selection).first;
    final thresholdIndex = requirement.options.indexWhere(
      (option) => option is BitcoinThresholdPolicyNode,
    );
    selection = policy.select(
      current: selection,
      requirement: requirement,
      selectedIndices: {thresholdIndex},
    );
  }
  return selection;
}

BitcoinPolicySelection _selectOptionContaining<T extends BitcoinPolicyNode>(
  BitcoinWalletPolicy policy,
) {
  var selection = const BitcoinPolicySelection.empty();
  while (policy.pathRequirements(selection).isNotEmpty) {
    final requirement = policy.pathSelectors(selection).first;
    final optionIndex = requirement.options.indexWhere(
      (option) => containsPolicyNode<T>(option),
    );
    if (optionIndex < 0) {
      throw StateError('No policy option contains $T');
    }
    selection = policy.select(
      current: selection,
      requirement: requirement,
      selectedIndices: {optionIndex},
    );
  }
  return selection;
}

String _replaceTaprootSignature(
  String psbtBase64,
  void Function(List<int> signature) mutate,
) {
  final psbt = bitcoin_base.Psbt.fromBase64(psbtBase64);
  final partial = psbt.input
      .getInputs<bitcoin_base.PsbtInputTaprootScriptSpendSignature>(
        0,
        bitcoin_base.PsbtInputTypes.taprootScriptSpentSignature,
      )!
      .single;
  final signature = partial.signature.toList();
  mutate(signature);
  psbt.input.updateInputs(0, [
    bitcoin_base.PsbtInputTaprootScriptSpendSignature(
      signature: signature,
      xOnlyPubKey: partial.xOnlyPubKey,
      leafHash: partial.leafHash,
    ),
  ]);
  return psbt.toBase64();
}

String _mutateTaprootControlBlock(String psbtBase64) {
  final psbt = bitcoin_base.Psbt.fromBase64(psbtBase64);
  final leaf = psbt.input
      .getInputs<bitcoin_base.PsbtInputTaprootLeafScript>(
        0,
        bitcoin_base.PsbtInputTypes.taprootLeafScript,
      )!
      .single;
  final controlBlock = leaf.controllBlock.toList()..[1] ^= 1;
  psbt.input.removeInputKeys(0, [
    bitcoin_base.PsbtInputTypes.taprootLeafScript,
  ]);
  psbt.input.updateInputs(0, [
    bitcoin_base.PsbtInputTaprootLeafScript(
      controllBlock: controlBlock,
      script: leaf.script,
      leafVersion: leaf.leafVersion,
    ),
  ]);
  return psbt.toBase64();
}

String _replaceTaprootKeySignature(
  String psbtBase64,
  void Function(List<int> signature) mutate,
) {
  final psbt = bitcoin_base.Psbt.fromBase64(psbtBase64);
  final partial = psbt.input
      .getInputs<bitcoin_base.PsbtInputTaprootKeySpendSignature>(
        0,
        bitcoin_base.PsbtInputTypes.taprootKeySpentSignature,
      )!
      .single;
  final signature = partial.signature.toList();
  mutate(signature);
  psbt.input.updateInputs(0, [
    bitcoin_base.PsbtInputTaprootKeySpendSignature(signature),
  ]);
  return psbt.toBase64();
}

String _withInputSighash(String psbtBase64, int sighash) {
  final psbt = bitcoin_base.Psbt.fromBase64(psbtBase64);
  psbt.input.updateInputs(0, [bitcoin_base.PsbtInputSigHash(sighash)]);
  return psbt.toBase64();
}

String _withoutInputSighash(String psbtBase64) {
  final psbt = bitcoin_base.Psbt.fromBase64(psbtBase64);
  psbt.input.removeInputKeys(0, [bitcoin_base.PsbtInputTypes.sighashType]);
  return psbt.toBase64();
}
