import 'package:wallet/wallet.dart';
import 'package:primitives/primitives.dart' show Outpoint;
import 'package:bb_mobile/features/coins/public/coins_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart'
    show WalletFreezePort;
import 'package:get_it/get_it.dart';

/// Bridges Labels to wallet freeze storage and label-enriched coin reads.
class WalletFreezeAdapter implements WalletFreezePort {
  final WalletFreezeStorePort _datasource;
  final LabeledWalletUtxoRepository _walletUtxoRepository;

  WalletFreezeAdapter({
    required this._datasource,
    required this._walletUtxoRepository,
  });

  @override
  Future<List<({String walletId, String txId, int vout})>> getAllFrozen() =>
      _datasource.getAllFrozen();

  @override
  Future<void> freeze(
    List<({String? walletId, String txId, int vout})> outputs,
  ) async {
    // Group by attributed wallet so each wallet's freezes write in one batch.
    // A null/empty origin stores under '' — inert until some wallet owns the
    // coin, matched by outpoint either way (it can never be auto-attributed or
    // cleaned up on wallet deletion; this is the documented degraded import).
    final byWallet = <String, List<Outpoint>>{};
    for (final o in outputs) {
      (byWallet[o.walletId ?? ''] ??= []).add((txId: o.txId, vout: o.vout));
    }
    for (final entry in byWallet.entries) {
      await _datasource.freezeOutpoints(
        walletId: entry.key,
        outpoints: entry.value,
      );
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

void registerWalletFreezeAdapter(GetIt locator) {
  locator.registerLazySingleton<WalletFreezePort>(
    () => WalletFreezeAdapter(
      datasource: locator<WalletFreezeStorePort>(),
      walletUtxoRepository: locator<LabeledWalletUtxoRepository>(),
    ),
  );
}
