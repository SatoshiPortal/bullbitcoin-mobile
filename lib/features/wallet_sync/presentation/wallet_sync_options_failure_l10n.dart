import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_options_failure.dart';
import 'package:bull_ui/bull_ui.dart' show BuildContext;

extension WalletSyncOptionsFailureL10n on WalletSyncOptionsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    WalletSyncNoPeersFailure() => context.loc.syncNoPeers(
      context.loc.syncUnknownTime,
    ),
    WalletSyncTorFailure() => context.loc.syncTorPaused,
    WalletSyncPausedFailure() => context.loc.syncPaused,
    WalletSyncUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
    WalletSyncOptionsStorageFailure() => context.loc.settingsErrorSavingSetting,
    WalletSyncOptionsInvalidBirthdayFailure() =>
      context.loc.oopsSomethingWentWrong,
  };
}
