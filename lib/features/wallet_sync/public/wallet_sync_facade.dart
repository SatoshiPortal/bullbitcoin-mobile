import 'package:go_router/go_router.dart';
import '../domain/usecases/watch_wallet_sync_status_usecase.dart';
import '../domain/usecases/start_wallet_sync_usecase.dart';
import '../ui/wallet_sync_status_view.dart';
import '../domain/usecases/watch_cbf_network_policy_usecase.dart';
import '../domain/usecases/set_cbf_wifi_only_usecase.dart';
import '../domain/usecases/continue_cbf_on_mobile_data_usecase.dart';
import '../ui/wallet_sync_network_preferences.dart';
import '../wallet_sync_router.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/get_wallet_sync_network_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/load_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/save_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/ui/wallet_sync_settings_section.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_selection.dart';
import 'package:bb_mobile/features/wallet_sync/ui/wallet_sync_options_sheet.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';

export '../domain/wallet_sync_selection.dart';

/// Shared choices and per-wallet sync presentation. Reads remain local; retry and saving preferences explicitly start foreground synchronization.
class WalletSyncFacade {
  final GetWalletSyncNetworkUsecase _network;
  final LoadWalletSyncSettingsUsecase _load;
  final SaveWalletSyncSettingsUsecase _save;
  final WatchWalletSyncStatusUsecase _watch;
  final StartWalletSyncUsecase _start;
  final WatchCbfNetworkPolicyUsecase? _watchNetwork;
  final SetCbfWifiOnlyUsecase? _setWifiOnly;
  final ContinueCbfOnMobileDataUsecase? _continueOnMobileData;

  WalletSyncFacade({
    required this._network,
    required this._load,
    required this._save,
    required this._watch,
    required this._start,
    this._watchNetwork,
    this._setWifiOnly,
    this._continueOnMobileData,
  });

  Widget settingsForWallet(String walletId) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _status(walletId, WalletSyncViewKind.status),
      const Gap(BullSpacing.md),
      WalletSyncSettingsSection(
        walletId: walletId,
        load: _load,
        save: _save,
        choose: choose,
        networkPreferences: switch ((
          _watchNetwork,
          _setWifiOnly,
          _continueOnMobileData,
        )) {
          (final watch?, final set?, final resume?) =>
            WalletSyncNetworkPreferences(
              watch: watch,
              set: set,
              continueOnMobileData: resume,
            ),
          _ => null,
        },
      ),
    ],
  );

  Widget cardSyncForWallet(String walletId, {required bool isSyncing}) =>
      _status(walletId, WalletSyncViewKind.card, isSyncing: isSyncing);

  Widget recoveryForWallet(String walletId) =>
      _status(walletId, WalletSyncViewKind.recovery);
  Widget incompleteBalanceForWallet(String walletId, {bool sending = false}) =>
      _status(
        walletId,
        sending
            ? WalletSyncViewKind.sendWarning
            : WalletSyncViewKind.incomplete,
      );
  Widget networkStatusForWallet(String walletId) =>
      _status(walletId, WalletSyncViewKind.network);

  Widget _status(
    String walletId,
    WalletSyncViewKind kind, {
    bool isSyncing = false,
  }) => Builder(
    builder: (context) => WalletSyncStatusView(
      walletId: walletId,
      watch: _watch,
      start: _start,
      continueOnMobileData: _continueOnMobileData,
      kind: kind,
      isSyncing: isSyncing,
      onSettings: () => openSettings(context, walletId),
      onNetwork: () => context.pushNamed(
        WalletSyncRouter.statusRouteName,
        pathParameters: {'walletId': walletId},
      ),
    ),
  );

  Future<void> openSettings(BuildContext context, String walletId) async {
    await BullBottomSheet.show<void>(
      context: context,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(BullSpacing.lg),
            child: settingsForWallet(walletId),
          ),
        ),
      ),
    );
  }

  Widget receiveNote(String walletId) =>
      _status(walletId, WalletSyncViewKind.receiveNote);
  Widget sendReviewForWallet(String walletId) =>
      _status(walletId, WalletSyncViewKind.sendReview);

  Future<WalletSyncSelection?> choose(
    BuildContext context, {
    BitcoinNetwork? network,
    bool askScriptType = false,
    WalletSyncSelection initial = const WalletSyncSelection(),
    bool changingSource = false,
  }) async {
    final BitcoinNetwork selectedNetwork;
    if (network != null) {
      selectedNetwork = network;
    } else {
      switch (await _network.execute()) {
        case Ok(:final value):
          selectedNetwork = value;
        case Err():
          if (context.mounted) {
            BullSnackBar.show(
              context,
              message: context.loc.oopsSomethingWentWrong,
            );
          }
          return null;
      }
    }
    if (!context.mounted) return null;
    return BullBottomSheet.show<WalletSyncSelection>(
      context: context,
      child: WalletSyncOptionsSheet(
        network: selectedNetwork,
        askScriptType: askScriptType,
        initial: initial,
        changingSource: changingSource,
      ),
    );
  }
}
