import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

class LiquidWalletRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final SeedDatasource _seed;
  final LwkWalletDatasource _lwkWallet;
  final WalletSourceOperationCoordinator _coordinator;

  LiquidWalletRepository({
    required this._walletMetadataDatasource,
    required SeedDatasource seedDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required this._coordinator,
  }) : _seed = seedDatasource,
       _lwkWallet = lwkWalletDatasource;

  Future<String> buildPset({
    required String walletId,
    required String address,
    int? amountSat,
    required RelativeFee feeRate,
    bool? drain,
  }) async {
    final metadata = await _liquidMetadata(walletId);

    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    final pset = await _coordinator.runExclusive(
      _sourceKey(metadata),
      (_) => _lwkWallet.buildPset(
        wallet: wallet,
        address: address,
        amountSat: amountSat,
        feeRate: feeRate,
        drain: drain ?? false,
      ),
    );

    return pset;
  }

  Future<(int, int)> getPsetSizeAndAbsoluteFees({required String pset}) async {
    final (size, fees) = await _lwkWallet.decodeAbsoluteFeesFromPset(pset);
    return (size, fees);
  }

  Future<int> getLbtcUtxoCount({required String walletId}) async {
    final metadata = await _liquidMetadata(walletId);
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    return _coordinator.runExclusive(
      _sourceKey(metadata),
      (_) => _lwkWallet.getLbtcUtxoCount(wallet: wallet),
    );
  }

  Future<List<String>> consolidate({
    required String walletId,
    required RelativeFee feeRate,
    required int highUtxoThreshold,
    required int maximumInputs,
  }) async {
    final metadata = await _liquidMetadata(walletId);
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    return _coordinator.runExclusive(
      _sourceKey(metadata),
      (_) => _lwkWallet.consolidate(
        wallet: wallet,
        feeRate: feeRate,
        highUtxoThreshold: highUtxoThreshold,
        maximumInputs: maximumInputs,
      ),
    );
  }

  Future<String> signPset({
    required String pset,
    required String walletId,
  }) async {
    final metadata = await _liquidMetadata(walletId);
    final signedPsbt = await _coordinator.runExclusive(_sourceKey(metadata), (
      _,
    ) async {
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
      return _lwkWallet.signPset(wallet: wallet, pset);
    });

    return signedPsbt;
  }

  Future<int> getAmountSentToAddress({
    required String pset,
    required String address,
    required String walletId,
  }) async {
    final metadata = await _liquidMetadata(walletId);
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      isTestnet: metadata.isTestnet,
      id: metadata.id,
    );
    return _coordinator.runExclusive(
      _sourceKey(metadata),
      (_) => _lwkWallet.getAmountSentToAddress(pset, address, wallet: wallet),
    );
  }

  WalletSourceKey _sourceKey(WalletMetadataModel metadata) => WalletSourceKey(
    metadata.id,
    'liquid',
    metadata.isTestnet ? 'testnet' : 'mainnet',
  );

  Future<WalletMetadataModel> _liquidMetadata(String walletId) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    return metadata;
  }
}
