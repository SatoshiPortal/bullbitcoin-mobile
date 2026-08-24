import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_coin_selection_exception.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_psbt_review_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bitcoin_base/bitcoin_base.dart' as bitcoin_base;
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../bdk_wallet_test_fixture.dart';
import '../../wallet_signer_test_fixture.dart';

final class _TestPathProvider extends PathProviderPlatform {
  final String path;

  _TestPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

final class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

final class _MockSeedDatasource extends Mock implements SeedDatasource {}

final class _MockFrozenWalletUtxoDatasource extends Mock
    implements FrozenWalletUtxoDatasource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late PathProviderPlatform originalPathProvider;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync(
      'bdk_coin_selection_test',
    );
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPathProvider(tempDirectory.path);
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    tempDirectory.deleteSync(recursive: true);
  });

  test(
    'does not add another wallet coin to an insufficient selection',
    () async {
      final descriptors = singleSignatureDescriptors(testMnemonics.first);
      final walletModel =
          WalletModel.publicBdk(
                id: 'manual-selection',
                descriptor: twoPathDescriptor(
                  descriptors.external,
                  descriptors.internal,
                ),
                isTestnet: true,
              )
              as PublicBdkWalletModel;
      final wallet = await BdkFacade.createWallet(walletModel);
      final receivingAddress = wallet.peekAddress(
        keychain: bdk.KeychainKind.external_,
        index: 0,
      );
      wallet.applyUnconfirmedTxs(
        unconfirmedTxs: [
          bdk.UnconfirmedTx(
            tx: fundingTransaction(
              receivingAddress.address.scriptPubkey(),
              previousTxByte: 0x31,
            ),
            lastSeen: 1,
          ),
          bdk.UnconfirmedTx(
            tx: fundingTransaction(
              receivingAddress.address.scriptPubkey(),
              previousTxByte: 0x32,
            ),
            lastSeen: 2,
          ),
        ],
      );
      await BdkFacade.saveWallet(wallet, walletModel.hexId);
      final selected = wallet.listUnspent().first;
      final recipient = wallet.peekAddress(
        keychain: bdk.KeychainKind.external_,
        index: 1,
      );
      final recipientAddress = recipient.address.toString();
      final receivingAddressString = receivingAddress.address.toString();
      wallet.dispose();

      final datasource = BdkWalletDatasource();
      await expectLater(
        datasource.buildPsbt(
          address: recipientAddress,
          amountSat: 150000,
          networkFee: const NetworkFee.absolute(1000),
          selected: [
            WalletUtxoModel.bitcoin(
              txId: selected.outpoint.txid.toString(),
              vout: selected.outpoint.vout,
              amountSat: BigInt.from(100000),
              scriptPubkey: Uint8List(0),
              address: receivingAddressString,
              isExternalKeyChain: true,
            ),
          ],
          wallet: walletModel,
        ),
        throwsA(isA<SelectedBitcoinCoinsInsufficientException>()),
      );
    },
  );

  test('rejects a witness UTXO that differs from the wallet output', () async {
    final descriptors = singleSignatureDescriptors(testMnemonics.first);
    final walletModel =
        WalletModel.publicBdk(
              id: 'witness-utxo-validation',
              descriptor: twoPathDescriptor(
                descriptors.external,
                descriptors.internal,
              ),
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final wallet = await BdkFacade.createWallet(walletModel);
    final receivingAddress = wallet.peekAddress(
      keychain: bdk.KeychainKind.external_,
      index: 0,
    );
    final recipient = wallet.peekAddress(
      keychain: bdk.KeychainKind.external_,
      index: 1,
    );
    wallet.applyUnconfirmedTxs(
      unconfirmedTxs: [
        bdk.UnconfirmedTx(
          tx: fundingTransaction(receivingAddress.address.scriptPubkey()),
          lastSeen: 1,
        ),
      ],
    );
    await BdkFacade.saveWallet(wallet, walletModel.hexId);
    wallet.dispose();

    final datasource = BdkWalletDatasource();
    final psbtBase64 = await datasource.buildPsbt(
      wallet: walletModel,
      address: recipient.address.toString(),
      amountSat: 50000,
      networkFee: const NetworkFee.absolute(1000),
    );
    final psbt = bitcoin_base.Psbt.fromBase64(psbtBase64);
    final witnessUtxo = psbt.input.getInput<bitcoin_base.PsbtInputWitnessUtxo>(
      0,
      bitcoin_base.PsbtInputTypes.witnessUTXO,
    )!;
    psbt.input.updateInputs(0, [
      bitcoin_base.PsbtInputWitnessUtxo(
        amount: witnessUtxo.amount + BigInt.one,
        scriptPubKey: witnessUtxo.scriptPubKey,
      ),
    ]);

    await expectLater(
      datasource.validateWalletPsbtInputs(psbt.toBase64(), wallet: walletModel),
      throwsA(isA<InvalidBitcoinPsbtException>()),
    );
  });

  test('rejects a PSBT that repeats a wallet input', () async {
    final descriptors = singleSignatureDescriptors(testMnemonics.first);
    final walletModel =
        WalletModel.publicBdk(
              id: 'duplicate-input-validation',
              descriptor: twoPathDescriptor(
                descriptors.external,
                descriptors.internal,
              ),
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final wallet = await BdkFacade.createWallet(walletModel);
    final receivingAddress = wallet.peekAddress(
      keychain: bdk.KeychainKind.external_,
      index: 0,
    );
    final recipient = wallet.peekAddress(
      keychain: bdk.KeychainKind.external_,
      index: 1,
    );
    wallet.applyUnconfirmedTxs(
      unconfirmedTxs: [
        bdk.UnconfirmedTx(
          tx: fundingTransaction(receivingAddress.address.scriptPubkey()),
          lastSeen: 1,
        ),
      ],
    );
    await BdkFacade.saveWallet(wallet, walletModel.hexId);
    wallet.dispose();
    final datasource = BdkWalletDatasource();
    final psbtBase64 = await datasource.buildPsbt(
      wallet: walletModel,
      address: recipient.address.toString(),
      amountSat: 50000,
      networkFee: const NetworkFee.absolute(1000),
    );
    final psbt = bitcoin_base.Psbt.fromBase64(psbtBase64);
    final unsignedTransaction = psbt.global
        .getGlobal<bitcoin_base.PsbtGlobalUnsignedTransaction>(
          bitcoin_base.PsbtGlobalTypes.unsignedTx,
        )!;
    final duplicateTransaction = unsignedTransaction.transaction.copyWith(
      inputs: [
        ...unsignedTransaction.transaction.inputs,
        unsignedTransaction.transaction.inputs.single.copyWith(),
      ],
    );
    final duplicateInputPsbt = bitcoin_base.Psbt(
      global: bitcoin_base.PsbtGlobal(
        entries: [
          for (final entry in psbt.global.entries)
            if (entry.type != bitcoin_base.PsbtGlobalTypes.unsignedTx) entry,
          bitcoin_base.PsbtGlobalUnsignedTransaction(duplicateTransaction),
        ],
        version: psbt.version,
      ),
      input: bitcoin_base.PsbtInput(
        entries: [...psbt.input.entries, psbt.input.entries.single],
        version: psbt.version,
      ),
      output: bitcoin_base.PsbtOutput(
        entries: psbt.output.entries,
        version: psbt.version,
      ),
    );

    await expectLater(
      datasource.validateWalletPsbtInputs(
        duplicateInputPsbt.toBase64(),
        wallet: walletModel,
      ),
      throwsA(isA<InvalidBitcoinPsbtException>()),
    );
  });

  test(
    'validates the spent inputs of the transaction being replaced',
    () async {
      final descriptors = singleSignatureDescriptors(testMnemonics.first);
      final walletModel =
          WalletModel.publicBdk(
                id: 'replacement-input-validation',
                descriptor: twoPathDescriptor(
                  descriptors.external,
                  descriptors.internal,
                ),
                isTestnet: true,
              )
              as PublicBdkWalletModel;
      final wallet = await BdkFacade.createWallet(walletModel);
      final receivingAddress = wallet.peekAddress(
        keychain: bdk.KeychainKind.external_,
        index: 0,
      );
      final recipient = wallet.peekAddress(
        keychain: bdk.KeychainKind.external_,
        index: 1,
      );
      wallet.applyUnconfirmedTxs(
        unconfirmedTxs: [
          bdk.UnconfirmedTx(
            tx: fundingTransaction(receivingAddress.address.scriptPubkey()),
            lastSeen: 1,
          ),
        ],
      );
      await BdkFacade.saveWallet(wallet, walletModel.hexId);

      final datasource = BdkWalletDatasource();
      final originalPsbt = await datasource.buildPsbt(
        wallet: walletModel,
        address: recipient.address.toString(),
        amountSat: 50000,
        networkFee: const NetworkFee.absolute(1000),
      );
      final parsedOriginal = bdk.Psbt(psbtBase64: originalPsbt);
      final originalTransaction = parsedOriginal.extractTx();
      final originalTxid = originalTransaction.computeTxid().toString();
      wallet.applyUnconfirmedTxs(
        unconfirmedTxs: [
          bdk.UnconfirmedTx(tx: originalTransaction, lastSeen: 2),
        ],
      );
      await BdkFacade.saveWallet(wallet, walletModel.hexId);
      parsedOriginal.dispose();
      wallet.dispose();

      await expectLater(
        datasource.validateWalletPsbtInputs(originalPsbt, wallet: walletModel),
        throwsA(isA<BitcoinPsbtMissingUtxoException>()),
      );
      await datasource.validateWalletPsbtInputs(
        originalPsbt,
        wallet: walletModel,
        allowSpentWalletInputs: true,
      );

      final metadata = WalletMetadataModel(
        id: walletModel.id,
        network: Network.bitcoinTestnet,
        signers: [
          walletSignerModel(
            id: 'local-signer',
            descriptorKeyId: 'local-key',
            masterFingerprint: descriptors.fingerprint,
            xpubFingerprint: descriptors.fingerprint,
            xpub: descriptors.xpub,
            derivationPath: "m/84'/1'/0'",
            descriptorPath: standardSingleSignatureDescriptorPath,
            signer: Signer.local,
            signerDevice: null,
          ),
        ],
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        publicDescriptor: walletModel.descriptor,
        isDefault: false,
      );
      final metadataDatasource = _MockWalletMetadataDatasource();
      final seedDatasource = _MockSeedDatasource();
      final frozenDatasource = _MockFrozenWalletUtxoDatasource();
      when(
        () => metadataDatasource.fetch(metadata.id),
      ).thenAnswer((_) async => metadata);
      when(() => seedDatasource.get(descriptors.fingerprint)).thenAnswer(
        (_) async =>
            SeedModel.mnemonic(mnemonicWords: testMnemonics.first.split(' ')),
      );
      when(() => frozenDatasource.getAllFrozen()).thenAnswer((_) async => []);
      final repository = BitcoinWalletRepository(
        walletMetadataDatasource: metadataDatasource,
        seedDatasource: seedDatasource,
        bdkWalletDatasource: datasource,
        frozenWalletUtxoDatasource: frozenDatasource,
      );

      final replacementPsbt = await repository.bumpFee(
        walletId: metadata.id,
        txid: originalTxid,
        newFeeRate: const RelativeFee(2500),
      );

      final replacement = bdk.Psbt(psbtBase64: replacementPsbt);
      expect(
        replacement.input().every(
          (input) =>
              input.finalScriptSig != null || input.finalScriptWitness != null,
        ),
        isTrue,
      );
      replacement.dispose();
    },
  );
}
