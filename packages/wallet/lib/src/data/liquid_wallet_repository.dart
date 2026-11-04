import 'package:primitives/primitives.dart' show RelativeFee;
import 'package:wallet/wallet.dart';
import 'package:transaction_sync/transaction_sync.dart';

class LiquidWalletRepository {
  final WalletCatalogPort _walletMetadataDatasource;
  final WalletSigningPort _signing;
  final LwkWalletDatasource _lwkWallet;
  final WalletSourceOperationCoordinator _coordinator;

  LiquidWalletRepository({
    required this._walletMetadataDatasource,
    required this._signing,
    required LwkWalletDatasource lwkWalletDatasource,
    required this._coordinator,
  }) : _lwkWallet = lwkWalletDatasource;

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
      return _signing.signPset(pset, metadata: metadata);
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

  WalletSourceKey _sourceKey(WalletMetadata metadata) => WalletSourceKey(
    metadata.id,
    'liquid',
    metadata.isTestnet ? 'testnet' : 'mainnet',
  );

  Future<WalletMetadata> _liquidMetadata(String walletId) async {
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
