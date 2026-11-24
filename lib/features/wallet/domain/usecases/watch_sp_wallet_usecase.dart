import 'package:silent/silent.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';

/// Wallet feature's own use case wrapping the Silent Payments facade update
/// stream, so the `WalletBloc` observes SP changes without SP ever pushing
/// into the wallet (AGENTS.md rule #3: watcher -> use case -> repo).
class WatchSpWalletUsecase {
  final Silent _silent;

  WatchSpWalletUsecase({required this._silent});

  Stream<Result<SilentUpdate, WalletFailure>> execute() =>
      _silent.watchUpdates().map(
        (result) => result.mapErr(
          (_) => const WalletStorageFailure('Silent updates unavailable'),
        ),
      );
}
