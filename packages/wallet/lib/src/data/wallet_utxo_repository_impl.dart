import 'package:wallet/wallet.dart';
import 'wallet_coin_mapper.dart';
import 'package:primitives/primitives.dart' show Outpoint;
import 'package:transaction_sync/transaction_sync.dart'
    show WalletSourceKey, WalletSourceOperationCoordinator;

class WalletUtxoRepositoryImpl implements WalletUtxoRepository {
  final WalletCatalogPort _walletMetadataDatasource;
  final BdkWalletDatasource _bdkWalletDatasource;
  final LwkWalletDatasource _lwkWalletDatasource;
  final WalletFreezeStorePort _frozenWalletUtxoDatasource;
  final WalletSourceOperationCoordinator _coordinator;

  WalletUtxoRepositoryImpl({
    required this._walletMetadataDatasource,
    required this._bdkWalletDatasource,
    required this._lwkWalletDatasource,
    required this._frozenWalletUtxoDatasource,
    required this._coordinator,
  });

  @override
  Future<List<WalletCoin>> getWalletUtxos({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    final walletModel = metadata.isBitcoin
        ? WalletModel.publicBdk(
            externalDescriptor: metadata.externalPublicDescriptor,
            internalDescriptor: metadata.internalPublicDescriptor,
            isTestnet: metadata.isTestnet,
            id: metadata.id,
          )
        : WalletModel.publicLwk(
            combinedCtDescriptor: metadata.externalPublicDescriptor,
            isTestnet: metadata.isTestnet,
            id: metadata.id,
          );

    final utxoModels = await _coordinator.runExclusive(
      WalletSourceKey(
        walletModel.id,
        walletModel is PublicBdkWalletModel ? 'bitcoin' : 'liquid',
        walletModel.isTestnet ? 'testnet' : 'mainnet',
      ),
      (_) => metadata.isBitcoin
          ? _bdkWalletDatasource.getUtxos(wallet: walletModel)
          : _lwkWalletDatasource.getUtxos(wallet: walletModel),
    );
    // `isFrozen` is matched by outpoint against the global frozen set (an
    // outpoint is globally unique, so it belongs to one wallet anyway). Frozen
    // rows for coins this wallet doesn't hold simply never match. Materialise
    // as a Set for O(1) membership — Outpoint is a record, so it has structural
    // equality/hashCode and keys the set directly.
    final frozenOutpoints = (await _frozenWalletUtxoDatasource.getAllFrozen())
        .map((row) => (txId: row.txId, vout: row.vout))
        .toSet();

    final utxos = utxoModels
        .map(
          (model) => WalletCoinMapper.toEntity(
            model,
            walletId: walletId,
            isFrozen: frozenOutpoints.contains((
              txId: model.txId,
              vout: model.vout,
            )),
          ),
        )
        .toList();

    return utxos;
  }

  @override
  Future<void> freezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  }) {
    return _frozenWalletUtxoDatasource.freezeOutpoints(
      walletId: walletId,
      outpoints: outpoints,
    );
  }

  @override
  Future<void> unfreezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  }) {
    return _frozenWalletUtxoDatasource.unfreezeOutpoints(
      walletId: walletId,
      outpoints: outpoints,
    );
  }

  @override
  Future<List<Outpoint>> getAllFrozenOutpoints() async {
    final rows = await _frozenWalletUtxoDatasource.getAllFrozen();
    return rows.map((row) => (txId: row.txId, vout: row.vout)).toList();
  }
}
