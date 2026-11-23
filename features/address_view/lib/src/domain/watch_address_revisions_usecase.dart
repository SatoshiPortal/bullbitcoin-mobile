import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import 'resolve_address_wallet_usecase.dart';

/// Invalidates the address projection without scheduling a network read.
final class WatchAddressRevisionsUsecase {
  final ResolveAddressWalletUsecase _resolveWallet;
  final Stream<WalletRevisionState> _changes;

  const WatchAddressRevisionsUsecase(this._resolveWallet, this._changes);

  Stream<void> execute(String id) => _changes
      .where((change) => change.stamp.key.id == id)
      .asyncMap((change) async {
        final wallet = await _resolveWallet.execute(id);
        return switch (wallet) {
          Ok(:final value) => value == change.stamp.key,
          Err() => false,
        };
      })
      .where((matches) => matches)
      .map((_) {});
}
