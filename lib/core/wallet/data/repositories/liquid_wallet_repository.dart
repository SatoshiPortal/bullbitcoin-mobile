import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/liquid_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/selected_inputs_unavailable_exception.dart';

class LiquidWalletRepository implements LiquidSendPort {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final SeedDatasource _seed;
  final LwkWalletDatasource _lwkWallet;
  final FrozenWalletUtxoDatasource _frozenWalletUtxoDatasource;

  LiquidWalletRepository({
    required this._walletMetadataDatasource,
    required SeedDatasource seedDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required this._frozenWalletUtxoDatasource,
  }) : _seed = seedDatasource,
       _lwkWallet = lwkWalletDatasource;

  @override
  Future<String> buildPset({
    required String walletId,
    required String address,
    int? amountSat,
    required RelativeFee feeRate,
    bool? drain,
    Set<Outpoint>? selectedInputs,
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
    final frozen = await _frozenOutpoints();
    Set<Outpoint>? inputs = selectedInputs;
    if (selectedInputs != null || frozen.isNotEmpty) {
      final available = {
        for (final utxo in await _lwkWallet.getUtxos(wallet: wallet))
          if (!frozen.contains((txId: utxo.txId, vout: utxo.vout)))
            (txId: utxo.txId, vout: utxo.vout),
      };
      if (selectedInputs != null &&
          (selectedInputs.isEmpty || !available.containsAll(selectedInputs))) {
        throw SelectedInputsUnavailableException(
          'Selected Liquid coins are unavailable',
        );
      }
      inputs ??= available;
      if (inputs.isEmpty) {
        throw NoSpendableUtxoException('No spendable Liquid coins');
      }
    }
    final pset = await _lwkWallet.buildPset(
      wallet: wallet,
      address: address,
      amountSat: amountSat,
      feeRate: feeRate,
      drain: drain ?? false,
      selectedInputs: inputs,
    );

    return pset;
  }

  Future<(int, int)> getPsetSizeAndAbsoluteFees({required String pset}) async {
    final (size, fees) = await _lwkWallet.decodeAbsoluteFeesFromPset(pset);
    return (size, fees);
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
      unspendable: await _frozenOutpoints(),
    );
  }

  Future<String> signPset({
    required String pset,
    required String walletId,
  }) async {
    final frozen = await _frozenOutpoints();
    if (frozen.isNotEmpty &&
        _lwkWallet.getPsetInputs(pset).any(frozen.contains)) {
      throw NoSpendableUtxoException(
        'The transaction spends a frozen Liquid coin',
      );
    }
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

  Future<Set<Outpoint>> _frozenOutpoints() async => {
    for (final utxo in await _frozenWalletUtxoDatasource.getAllFrozen())
      (txId: utxo.txId, vout: utxo.vout),
  };

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
