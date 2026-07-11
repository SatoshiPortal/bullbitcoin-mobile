import 'package:bb_mobile/features/sp/public/sp_facade.dart';

// Re-export the public SP update type so this feature's bloc consumes it
// without reaching into the SP feature's `domain/`.
export 'package:bb_mobile/features/sp/public/sp_facade.dart'
    show SpUpdate, SpBalanceChanged, SpSetupChanged;

/// Wallet feature's own use case wrapping the Silent Payments facade update
/// stream, so the `WalletBloc` observes SP changes without SP ever pushing
/// into the wallet (AGENTS.md rule #3: watcher -> use case -> repo).
class WatchSpWalletUsecase {
  final SpFacade _spFacade;

  WatchSpWalletUsecase({required this._spFacade});

  Stream<SpUpdate> execute() => _spFacade.watchUpdates();
}
