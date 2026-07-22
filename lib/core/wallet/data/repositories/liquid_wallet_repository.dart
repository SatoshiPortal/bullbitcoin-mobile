import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/liquid_tx_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';

class LiquidWalletRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final SeedDatasource _seed;
  final LwkWalletDatasource _lwkWallet;

  LiquidWalletRepository({
    required this._walletMetadataDatasource,
    required SeedDatasource seedDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
  }) : _seed = seedDatasource,
       _lwkWallet = lwkWalletDatasource;

  Future<(int, int)> getPsetSizeAndAbsoluteFees({required String pset}) async {
    final (size, fees) = await _lwkWallet.decodeAbsoluteFeesFromPset(pset);
    return (size, fees);
  }

  /// The output index (vout) of the first output in [pset] with a plaintext
  /// value of exactly [satoshi], or null if none matches. Pure PSET decoding
  /// — not wallet-specific, so no metadata lookup is needed.
  int? findOutputIndexByAmount({required String pset, required int satoshi}) {
    return _lwkWallet.findOutputIndexByAmount(pset: pset, satoshi: satoshi);
  }

  /// Whether spending [utxoCount] confirmed L-BTC UTXOs in a single
  /// transaction would exceed the confidential-tx input limit — exposed
  /// here so a caller building via [buildCustomTx] (which has no built-in
  /// pre-check, since it takes an explicit UTXO list instead of letting LWK
  /// choose) can enforce it without needing to import the datasource itself
  /// just to read its constant.
  bool exceedsLiquidInputLimit(int utxoCount) =>
      utxoCount > LwkWalletDatasource.maxLiquidTxInputs;

  Future<int> getLbtcUtxoCount({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    return _lwkWallet.getLbtcUtxoCount(wallet: wallet);
  }

  /// Outpoints of the wallet's confirmed L-BTC UTXOs — the candidates for
  /// consolidation batching.
  Future<List<Outpoint>> getConfirmedLbtcOutpoints({
    required String walletId,
  }) async {
    final utxos = await _confirmedLbtcUtxos(walletId);
    return utxos.map((u) => (txId: u.txId, vout: u.vout)).toList();
  }

  /// Same candidates as [getConfirmedLbtcOutpoints], but with each UTXO's
  /// amount — for a caller that needs to distribute UTXOs across multiple
  /// batches *by value*, not just chunk them by position (a batch made up
  /// entirely of dust UTXOs can't even cover its own fee).
  Future<List<OutpointAmount>> getConfirmedLbtcOutpointAmounts({
    required String walletId,
  }) async {
    final utxos = await _confirmedLbtcUtxos(walletId);
    return utxos
        .map(
          (u) => (txId: u.txId, vout: u.vout, amountSat: u.amountSat.toInt()),
        )
        .toList();
  }

  Future<List<WalletUtxoModel>> _confirmedLbtcUtxos(String walletId) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    return _lwkWallet.getConfirmedLbtcUtxos(wallet: wallet);
  }

  /// Build a PSET spending exactly [utxos], paying [outputs], with any
  /// leftover L-BTC value (after outputs + fee) swept to [drainToAddress] if
  /// set.
  Future<String> buildCustomTx({
    required String walletId,
    required List<Outpoint> utxos,
    required List<LiquidTxOutput> outputs,
    String? drainToAddress,
    required RelativeFee feeRate,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    return _lwkWallet.buildCustomTx(
      wallet: wallet,
      utxos: utxos,
      outputs: outputs,
      drainToAddress: drainToAddress,
      feeRate: feeRate,
    );
  }

  Future<int> getLbtcUtxoCount({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    return _lwkWallet.getLbtcUtxoCount(wallet: wallet);
  }

  Future<List<String>> consolidate({
    required String walletId,
    required RelativeFee feeRate,
    required int highUtxoThreshold,
    required int maximumInputs,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    return _lwkWallet.consolidate(
      wallet: wallet,
      feeRate: feeRate,
      highUtxoThreshold: highUtxoThreshold,
      maximumInputs: maximumInputs,
    );
  }

  Future<String> signPset({
    required String pset,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }

    final seed =
        await _seed.get(metadata.masterFingerprint) as MnemonicSeedModel;
    final mnemonic = seed.mnemonicWords.join(' ');

    final wallet =
        WalletModel.privateLwk(
              id: metadata.id,
              mnemonic: mnemonic,
              isTestnet: metadata.isTestnet,
            )
            as PrivateLwkWalletModel;
    final signedPsbt = await _lwkWallet.signPset(wallet: wallet, pset);

    return signedPsbt;
  }

  Future<int> getAmountSentToAddress({
    required String pset,
    required String address,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    return await _lwkWallet.getAmountSentToAddress(
      pset,
      address,
      wallet: wallet,
    );
  }
}
