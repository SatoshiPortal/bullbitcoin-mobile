import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/labels/application/wallet_freeze_port.dart';

/// Implements [WalletFreezePort] over the freezes sync owns. Every call
/// throws [WalletSnapshotException] when the freeze store cannot answer.
class WalletFreezeAdapter implements WalletFreezePort {
  final Future<Sync> Function() _sync;
  final WalletUtxoRepository _walletUtxoRepository;

  WalletFreezeAdapter({
    required this._sync,
    required this._walletUtxoRepository,
  });

  @override
  Future<List<({String walletId, String txId, int vout})>>
  getAllFrozen() async => switch (await (await _sync()).coins.listFrozen()) {
    Ok(:final value) => [
      for (final row in value)
        (
          walletId: row.origin,
          txId: row.outpoint.txId,
          vout: row.outpoint.vout,
        ),
    ],
    Err(:final failure) => throw WalletSnapshotException(failure),
  };

  @override
  Future<void> freeze(
    List<({String? walletId, String txId, int vout})> outputs,
  ) async {
    // The origin is kept as given: a null one stores empty, inert until a
    // wallet holds the coin, matched by outpoint either way. The wallet id
    // IS its origin, so a known wallet's freeze is attributed as
    // `wallet.coins.freeze` would.
    final coins = (await _sync()).coins;
    for (final o in outputs) {
      final result = await coins.freeze((
        txId: o.txId,
        vout: o.vout,
      ), origin: o.walletId ?? '');
      if (result case Err(:final failure)) {
        throw WalletSnapshotException(failure);
      }
    }
  }

  @override
  Future<List<({String txId, int vout})>> getOwnedOutpoints({
    required String walletId,
  }) async {
    final utxos = await _walletUtxoRepository.getWalletUtxos(
      walletId: walletId,
    );
    return [
      for (final u in utxos)
        switch (u) {
          BitcoinWalletUtxo(:final txId, :final vout) => (
            txId: txId,
            vout: vout,
          ),
          LiquidWalletUtxo(:final txId, :final vout) => (
            txId: txId,
            vout: vout,
          ),
        },
    ];
  }
}
