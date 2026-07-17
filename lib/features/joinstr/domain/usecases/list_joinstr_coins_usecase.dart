import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_datasource.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_coin.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_node_context_usecase.dart';

/// Lists the wallet's spendable coins so the user can pick which one to feed
/// into a coinjoin, like the "Select a UTXO" step in joinstr-kmp and
/// floresta_wallet. Scanning runs over electrum through Tor, so it can take a
/// moment on first use.
class ListJoinstrCoinsUsecase {
  final JoinstrDatasource _datasource;
  final ResolveJoinstrNodeContextUsecase _resolveNodeContext;

  ListJoinstrCoinsUsecase({
    required this._datasource,
    required ResolveJoinstrNodeContextUsecase resolveNodeContextUsecase,
  }) : _resolveNodeContext = resolveNodeContextUsecase;

  Future<List<JoinstrCoin>> execute({required Wallet wallet}) async {
    final context = await _resolveNodeContext.execute(wallet: wallet);
    final coins = await _datasource.listCoins(
      wallet: wallet,
      mnemonic: context.mnemonic,
      electrumUrl: context.electrumUrl,
      proxy: context.proxy,
    );
    // Largest first, on a copy so the datasource's list is never mutated.
    return [...coins]..sort((a, b) => b.valueSat.compareTo(a.valueSat));
  }
}
