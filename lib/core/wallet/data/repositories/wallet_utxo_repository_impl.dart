import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_utxo_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class WalletUtxoRepositoryImpl implements WalletUtxoRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final LabelsFacade _labelsFacade;
  final BdkWalletDatasource _bdkWalletDatasource;
  final LwkWalletDatasource _lwkWalletDatasource;
  final FrozenWalletUtxoDatasource _frozenWalletUtxoDatasource;

  WalletUtxoRepositoryImpl({
    required this._walletMetadataDatasource,
    required this._labelsFacade,
    required this._bdkWalletDatasource,
    required this._lwkWalletDatasource,
    required this._frozenWalletUtxoDatasource,
  });

  @override
  Future<List<WalletUtxo>> getWalletUtxos({required String walletId}) async {
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

    final utxoModels = metadata.isBitcoin
        ? await _bdkWalletDatasource.getUtxos(wallet: walletModel)
        : await _lwkWalletDatasource.getUtxos(wallet: walletModel);
    // `isFrozen` is matched by outpoint against the global frozen set (an
    // outpoint is globally unique, so it belongs to one wallet anyway). Frozen
    // rows for coins this wallet doesn't hold simply never match. Materialise
    // as a Set for O(1) membership — Outpoint is a record, so it has structural
    // equality/hashCode and keys the set directly.
    final frozenOutpoints = (await _frozenWalletUtxoDatasource.getAllFrozen())
        .map((row) => (txId: row.txId, vout: row.vout))
        .toSet();

    // fetchByReference is an unindexed full scan of the labels table (there is
    // no index on reference), so the previous per-UTXO fetch ran 3-4 such scans
    // per coin. Read every label once and index by reference in memory instead.
    final labelsByReference = <String, List<Label>>{};
    for (final label in await _labelsFacade.fetchAll()) {
      (labelsByReference[label.reference] ??= <Label>[]).add(label);
    }

    final utxos = utxoModels.map((model) {
      final isFrozen = frozenOutpoints.contains((
        txId: model.txId,
        vout: model.vout,
      ));

      final List<Label> addressLabels = switch (model) {
        LiquidWalletUtxoModel _ => [
          ...?labelsByReference[model.standardAddress],
          ...?labelsByReference[model.confidentialAddress],
        ],
        BitcoinWalletUtxoModel _ =>
          labelsByReference[model.address] ?? const [],
      };

      return WalletUtxoMapper.toEntity(
        model,
        walletId: walletId,
        labels: labelsByReference[model.labelRef] ?? const [],
        txLabels: labelsByReference[model.txId] ?? const [],
        addressLabels: addressLabels,
        isFrozen: isFrozen,
      );
    }).toList();

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
