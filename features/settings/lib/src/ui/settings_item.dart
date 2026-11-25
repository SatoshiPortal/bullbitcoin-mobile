import 'package:all_seed_view/all_seed_view.dart';
import 'package:access/access.dart';
import 'package:background_tasks/background_tasks.dart'
    show backgroundSyncAvailable;
import 'package:primitives/primitives.dart';
import 'package:bull_ark/ark_ui.dart';
import 'package:settings/src/ui/widgets/ark_debug_notification.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:settings/src/l10n.dart';
import 'package:settings/src/settings_links.dart';
import 'package:backups/backups.dart';
import 'package:bip85/bip85.dart';
import 'package:send/send.dart';
import 'package:network/network.dart';
import 'package:fees_feature/fees_feature.dart' show FeesNavigation;
import 'package:bull_exchange/bull_exchange.dart';
import 'package:wallet_import/wallet_import.dart' show ImportNavigation;
import 'package:label_editor/label_editor.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:settings/src/presentation/bloc/settings_cubit.dart';
import 'package:settings/src/ui/settings_route.dart';
import 'package:settings/src/ui/widgets/exchange_testnet_basic_auth_dialog.dart';
import 'package:silent/silent.dart';
import 'package:silent/localizations.dart';
import 'package:swap_feature/swap_feature.dart' show SwapNavigation;
import 'package:transactions/routes.dart';
import 'package:settings/generated/l10n/settings_localizations.dart';
import 'package:settings/generated/l10n/settings_localizations_en.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bull_ui/bull_ui.dart' show BullSettingsEntryItem;

import '../settings_menu.dart';

enum SettingsItemId {
  exchange,
  exchangeAccountSettings,
  quickActions,
  backup,
  startBackup,
  recoverbull,
  labels,
  transactionHistory,
  walletSettings,
  appSettings,
  termsOfService,
  servicesStatus,
  importWallet,
  broadcastTransaction,
  payjoin,
  ark,
  autoswap,
  swaps,
  swapRestore,
  electrum,
  mempool,
  feeSource,
  testnetMode,
  seedViewer,
  bip85,
  sp,
  language,
  theme,
  currency,
  securityPin,
  logs,
  sourceCode,
  tor,
  screenPrivacy,
  devMode,
  testnetCredentials,
  arkDebugNotification,
  errorReporting,
  permissions,
}

enum SettingsItemSection { root, backup, wallet, app }

const walletSettingsItemOrder = [
  SettingsItemId.payjoin,
  SettingsItemId.ark,
  SettingsItemId.autoswap,
  SettingsItemId.swaps,
  SettingsItemId.swapRestore,
  SettingsItemId.importWallet,
  SettingsItemId.electrum,
  SettingsItemId.mempool,
  SettingsItemId.feeSource,
  SettingsItemId.broadcastTransaction,
];

typedef OpenSettingsItem = void Function(BuildContext context);

class SettingsItem {
  final SettingsItemId id;
  final SettingsItemSection section;
  final String title;
  final List<String> path;
  final IconData icon;
  final List<String> keywords;
  final bool isSuperuser;
  final bool isInlineControl;

  /// SVG asset drawn instead of [icon], for a glyph no icon font has.
  final String? iconAsset;
  final OpenSettingsItem _open;

  const SettingsItem({
    required this.id,
    required this.section,
    required this.title,
    required this.path,
    required this.icon,
    required OpenSettingsItem open,
    this.keywords = const [],
    this.isSuperuser = false,
    this.isInlineControl = false,
    this.iconAsset,
  }) : _open = open; // ignore: prefer_initializing_formals

  void open(BuildContext context) => _open(context);

  SettingsEntry hubEntry({Widget? homeIcon}) => SettingsEntry(
    id: id.name,
    title: title,
    breadcrumbs: path,
    icon: icon,
    open: open,
    keywords: keywords,
    showOnHome: section == SettingsItemSection.root,
    isSuperuser: isSuperuser,
    indicatesServiceHealth: id == SettingsItemId.servicesStatus,
    homeIcon: homeIcon,
  );

  Widget? assetIcon(BuildContext context, {Color? iconColor}) {
    final asset = iconAsset;
    if (asset == null) return null;
    return SvgPicture.asset(
      asset,
      package: 'settings',
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(
        iconColor ?? context.appColors.onSurface,
        BlendMode.srcIn,
      ),
    );
  }

  Widget buildTile(
    BuildContext context, {
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
  }) {
    return BullSettingsEntryItem(
      icon: icon,
      leading: assetIcon(context, iconColor: iconColor),
      iconColor: iconColor,
      textColor: textColor,
      title: title,
      isSuperUser: isSuperuser,
      trailing: trailing,
      onTap: isInlineControl ? null : () => open(context),
    );
  }
}

extension SettingsItemsX on Iterable<SettingsItem> {
  SettingsItem byId(SettingsItemId id) => firstWhere((item) => item.id == id);

  Iterable<SettingsItem> inSection(SettingsItemSection section) =>
      where((item) => item.section == section);
}

/// The settings registry for the current context.
///
/// Every settings screen goes through this instead of calling
/// [buildSettingsItems] with its own arguments, so the superuser and dev-mode
/// gating and the platform-dependent exchange title are decided in exactly one
/// place. Search depends on that: it surfaces items from every section at once,
/// so a screen-local approximation of these flags would show the wrong rows.
List<SettingsItem> settingsItemsOf(
  BuildContext context, {
  bool accountReady = false,
}) {
  final isSuperuser = context.select(
    (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
  );
  final isDevModeEnabled = context.select(
    (SettingsCubit cubit) => cubit.state.isDevModeEnabled ?? false,
  );

  final isSpWalletSetup = context.select(
    (SettingsCubit cubit) => cubit.state.isSpWalletSetup,
  );

  return buildSettingsItems(
    localization: context.loc,
    isSuperuser: isSuperuser,
    isDevModeEnabled: isDevModeEnabled,
    isSpWalletSetup: isSpWalletSetup,
    accountReady: accountReady,
    backgroundTasksAvailable: backgroundSyncAvailable,
    environment: context.select(
      (SettingsCubit cubit) => cubit.state.storedSettings?.activeNetwork,
    ),
  );
}

List<SettingsItem> buildSettingsItems({
  required SettingsLocalizations localization,
  bool isSuperuser = false,
  bool isDevModeEnabled = false,
  bool isSpWalletSetup = false,
  bool accountReady = false,
  bool backgroundTasksAvailable = false,
  required NetworkEnv? environment,
}) {
  final english = SettingsLocalizationsEn();
  final silent = silentCopy(localization.localeName);
  final feeSourceTitle = FeesNavigation.settingsTitle(localization.localeName);
  final arkTitle = arkLocalizationsForLanguage(localization.localeName).title;
  final rootSection = localization.settingsScreenTitle;
  final backupSection = localization.settingsBackupTitle;
  final walletSection = localization.settingsWalletTitle;
  final appSection = localization.settingsAppTitle;

  List<String> path(SettingsItemSection section, String title) =>
      switch (section) {
        SettingsItemSection.root => [rootSection, title],
        SettingsItemSection.backup => [rootSection, backupSection, title],
        SettingsItemSection.wallet => [rootSection, walletSection, title],
        SettingsItemSection.app => [rootSection, appSection, title],
      };

  return [
    SettingsItem(
      id: SettingsItemId.appSettings,
      section: SettingsItemSection.root,
      title: appSection,
      path: path(SettingsItemSection.root, appSection),
      icon: Icons.app_settings_alt,
      open: (context) => context.pushNamed(SettingsRoute.appSettings.name),
      keywords: _keywords(
        localization.settingsSearchAppSettingsKeywords,
        english.settingsSearchAppSettingsKeywords,
        [english.settingsAppTitle, english.settingsAppSettingsTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.backup,
      section: SettingsItemSection.root,
      title: backupSection,
      path: path(SettingsItemSection.root, backupSection),
      icon: Icons.backup_outlined,
      open: BackupsNavigation.open,
      keywords: _keywords(
        localization.settingsSearchBackupKeywords,
        english.settingsSearchBackupKeywords,
        [english.settingsBackupTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.startBackup,
      section: SettingsItemSection.backup,
      title: localization.backupSettingsStartBackup,
      path: path(
        SettingsItemSection.backup,
        localization.backupSettingsStartBackup,
      ),
      icon: Icons.save_as,
      open: (context) => BackupsNavigation.start(context),
      keywords: _keywords(
        localization.settingsSearchStartBackupKeywords,
        english.settingsSearchStartBackupKeywords,
        [english.backupSettingsStartBackup],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.recoverbull,
      section: SettingsItemSection.backup,
      title: localization.backupSettingsRecoverBullSettings,
      path: path(
        SettingsItemSection.backup,
        localization.backupSettingsRecoverBullSettings,
      ),
      icon: Icons.cloud_circle,
      open: (context) =>
          RecoverBullFeature.open(context, RecoverBullFlow.settings),
      keywords: _keywords(
        localization.settingsSearchRecoverbullKeywords,
        english.settingsSearchRecoverbullKeywords,
        [english.backupSettingsRecoverBullSettings],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.labels,
      section: SettingsItemSection.backup,
      title: localization.backupSettingsLabelsButton,
      path: path(
        SettingsItemSection.backup,
        localization.backupSettingsLabelsButton,
      ),
      icon: Icons.sell,
      open: LabelEditor.open,
      keywords: _keywords(
        localization.settingsSearchLabelsKeywords,
        english.settingsSearchLabelsKeywords,
        [english.backupSettingsLabelsButton],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.transactionHistory,
      section: SettingsItemSection.backup,
      title: localization.transactionHistoryTitle,
      path: path(
        SettingsItemSection.backup,
        localization.transactionHistoryTitle,
      ),
      icon: Icons.file_download,
      open: (context) => TransactionsNavigation.openExport(context),
      keywords: _keywords(
        localization.settingsSearchTransactionHistoryKeywords,
        english.settingsSearchTransactionHistoryKeywords,
        [english.transactionHistoryTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.walletSettings,
      section: SettingsItemSection.root,
      title: walletSection,
      path: path(SettingsItemSection.root, walletSection),
      icon: Icons.currency_bitcoin,
      open: (context) => context.pushNamed(SettingsRoute.walletSettings.name),
      keywords: _keywords(
        localization.settingsSearchWalletSettingsKeywords,
        english.settingsSearchWalletSettingsKeywords,
        [english.settingsWalletTitle, english.settingsWalletSettingsTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.exchange,
      section: SettingsItemSection.root,
      title: localization.settingsExchangeTitle,
      path: path(SettingsItemSection.root, localization.settingsExchangeTitle),
      icon: Icons.currency_exchange,
      open: ExchangeAccessSettingsNavigation.open,
      keywords: _keywords(
        localization.settingsSearchExchangeKeywords,
        english.settingsSearchExchangeKeywords,
        [
          english.settingsExchangeTitle,
          english.settingsExchangeSettingsTitle,
          english.settingsAccountSettingsTitle,
        ],
      ),
    ),
    if (accountReady)
      SettingsItem(
        id: SettingsItemId.exchangeAccountSettings,
        section: SettingsItemSection.root,
        title: localization.settingsAccountSettingsTitle,
        path: path(
          SettingsItemSection.root,
          localization.settingsAccountSettingsTitle,
        ),
        icon: Icons.account_circle_outlined,
        open: ExchangeSettingsRoute.home.open,
        keywords: [
          localization.settingsAccountSettingsTitle,
          english.settingsAccountSettingsTitle,
        ],
      ),
    SettingsItem(
      id: SettingsItemId.termsOfService,
      section: SettingsItemSection.root,
      title: localization.settingsTermsOfServiceTitle,
      path: path(
        SettingsItemSection.root,
        localization.settingsTermsOfServiceTitle,
      ),
      icon: Icons.description,
      open: (_) => launchUrl(
        Uri.parse(SettingsLinks.termsAndConditionsLink),
        mode: LaunchMode.inAppBrowserView,
      ),
      keywords: _keywords(
        localization.settingsSearchTermsOfServiceKeywords,
        english.settingsSearchTermsOfServiceKeywords,
        [english.settingsTermsOfServiceTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.servicesStatus,
      section: SettingsItemSection.root,
      title: localization.settingsServiceStatusTitle,
      path: path(
        SettingsItemSection.root,
        localization.settingsServiceStatusTitle,
      ),
      icon: Icons.monitor_heart,
      open: (context) =>
          NetworkNavigation.open(context, section: NetworkSection.status),
      keywords: _keywords(
        localization.settingsSearchServicesStatusKeywords,
        english.settingsSearchServicesStatusKeywords,
        [english.settingsServiceStatusTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.logs,
      section: SettingsItemSection.root,
      title: localization.logSettingsLogsTitle,
      path: path(SettingsItemSection.root, localization.logSettingsLogsTitle),
      icon: Icons.article,
      open: (context) => context.pushNamed('logs'),
      keywords: _keywords(
        localization.settingsSearchLogsKeywords,
        english.settingsSearchLogsKeywords,
        [english.logSettingsLogsTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.sourceCode,
      section: SettingsItemSection.root,
      title: localization.settingsSourceCodeTitle,
      path: path(
        SettingsItemSection.root,
        localization.settingsSourceCodeTitle,
      ),
      icon: Icons.code,
      iconAsset: 'assets/icons/github.svg',
      open: (_) => launchUrl(
        Uri.parse(SettingsLinks.githubSupportLink),
        mode: LaunchMode.externalApplication,
      ),
      keywords: [
        localization.settingsSourceCodeTitle,
        english.settingsSourceCodeTitle,
        'GitHub',
      ],
    ),
    SettingsItem(
      id: SettingsItemId.importWallet,
      section: SettingsItemSection.wallet,
      title: localization.walletSettingsImportWalletTitle,
      path: path(
        SettingsItemSection.wallet,
        localization.walletSettingsImportWalletTitle,
      ),
      icon: Icons.sim_card_download,
      open: (context) => ImportNavigation.open(context),
      keywords: _keywords(
        localization.settingsSearchImportWalletKeywords,
        english.settingsSearchImportWalletKeywords,
        [english.walletSettingsImportWalletTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.broadcastTransaction,
      section: SettingsItemSection.wallet,
      title: localization.bitcoinSettingsBroadcastTransactionTitle,
      path: path(
        SettingsItemSection.wallet,
        localization.bitcoinSettingsBroadcastTransactionTitle,
      ),
      icon: Icons.satellite_alt,
      open: (context) =>
          context.pushNamed(BroadcastSignedTxRoute.broadcastHome.name),
      keywords: _keywords(
        localization.settingsSearchBroadcastTransactionKeywords,
        english.settingsSearchBroadcastTransactionKeywords,
        [english.bitcoinSettingsBroadcastTransactionTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.ark,
      section: SettingsItemSection.wallet,
      title: arkTitle,
      path: path(SettingsItemSection.wallet, arkTitle),
      icon: Icons.account_balance_wallet_outlined,
      open: ArkNavigation.open,
    ),
    SettingsItem(
      id: SettingsItemId.payjoin,
      section: SettingsItemSection.wallet,
      title: localization.bitcoinSettingsPayjoinTitle,
      path: path(
        SettingsItemSection.wallet,
        localization.bitcoinSettingsPayjoinTitle,
      ),
      icon: Icons.compare_arrows,
      open: (context) => context.pushNamed(SettingsRoute.payjoinSettings.name),
      keywords: _keywords(
        localization.settingsSearchPayjoinKeywords,
        english.settingsSearchPayjoinKeywords,
        [english.bitcoinSettingsPayjoinTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.autoswap,
      section: SettingsItemSection.wallet,
      title: localization.bitcoinSettingsAutoTransferTitle,
      path: path(
        SettingsItemSection.wallet,
        localization.bitcoinSettingsAutoTransferTitle,
      ),
      icon: Icons.swap_vertical_circle,
      open: SwapNavigation.openAutoswapSettings,
      keywords: _keywords(
        localization.settingsSearchAutoswapKeywords,
        english.settingsSearchAutoswapKeywords,
        [
          english.bitcoinSettingsAutoTransferTitle,
          english.autoswapSettingsTitle,
        ],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.swaps,
      section: SettingsItemSection.wallet,
      title: SwapNavigation.settingsTitle(localization.localeName),
      path: path(
        SettingsItemSection.wallet,
        SwapNavigation.settingsTitle(localization.localeName),
      ),
      icon: Icons.swap_horiz,
      open: SwapNavigation.openSettings,
      keywords: _keywords(
        localization.settingsSearchSwapsKeywords,
        english.settingsSearchSwapsKeywords,
        [SwapNavigation.settingsTitle(english.localeName)],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.swapRestore,
      section: SettingsItemSection.wallet,
      title: localization.swapRestoreTitle,
      path: path(SettingsItemSection.wallet, localization.swapRestoreTitle),
      icon: Icons.restore,
      open: SwapNavigation.openRestore,
      keywords: _keywords(
        localization.settingsSearchSwapRestoreKeywords,
        english.settingsSearchSwapRestoreKeywords,
        [english.swapRestoreTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.electrum,
      section: SettingsItemSection.wallet,
      title: localization.bitcoinSettingsElectrumServerTitle,
      path: path(
        SettingsItemSection.wallet,
        localization.bitcoinSettingsElectrumServerTitle,
      ),
      icon: Icons.hub,
      open: (context) =>
          NetworkNavigation.open(context, section: NetworkSection.electrum),
      keywords: _keywords(
        localization.settingsSearchElectrumKeywords,
        english.settingsSearchElectrumKeywords,
        [english.bitcoinSettingsElectrumServerTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.mempool,
      section: SettingsItemSection.wallet,
      title: localization.bitcoinSettingsMempoolServerTitle,
      path: path(
        SettingsItemSection.wallet,
        localization.bitcoinSettingsMempoolServerTitle,
      ),
      icon: Icons.memory,
      open: (context) =>
          NetworkNavigation.open(context, section: NetworkSection.mempool),
      keywords: _keywords(
        localization.settingsSearchMempoolKeywords,
        english.settingsSearchMempoolKeywords,
        [english.bitcoinSettingsMempoolServerTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.feeSource,
      section: SettingsItemSection.wallet,
      title: feeSourceTitle,
      path: path(SettingsItemSection.wallet, feeSourceTitle),
      icon: Icons.tune,
      open: FeesNavigation.openSettings,
      keywords: [FeesNavigation.settingsTitle('en'), 'Electrum', 'Mempool'],
    ),
    if (isSuperuser)
      SettingsItem(
        id: SettingsItemId.seedViewer,
        section: SettingsItemSection.wallet,
        title: localization.allSeedViewTitle,
        path: path(SettingsItemSection.wallet, localization.allSeedViewTitle),
        icon: Icons.vpn_key,
        open: (context) =>
            context.pushNamed<void>(AllSeedViewRoute.allSeedView.name),
        keywords: _keywords(
          localization.settingsSearchSeedViewerKeywords,
          english.settingsSearchSeedViewerKeywords,
          [english.allSeedViewTitle],
        ),
        isSuperuser: true,
      ),
    if (isSuperuser && isDevModeEnabled)
      SettingsItem(
        id: SettingsItemId.bip85,
        section: SettingsItemSection.wallet,
        title: localization.bitcoinSettingsBip85EntropiesTitle,
        path: path(
          SettingsItemSection.wallet,
          localization.bitcoinSettingsBip85EntropiesTitle,
        ),
        icon: Icons.science,
        open: const Bip85Route().push,
        keywords: _keywords(
          localization.settingsSearchBip85Keywords,
          english.settingsSearchBip85Keywords,
          [english.bitcoinSettingsBip85EntropiesTitle],
        ),
        isSuperuser: true,
      ),
    // One row either way: it offers to create the SP wallet until there is one,
    // then opens its settings.
    if (isSuperuser && isDevModeEnabled)
      SettingsItem(
        id: SettingsItemId.sp,
        section: SettingsItemSection.wallet,
        title: isSpWalletSetup
            ? silent.silentSettingsTitle
            : silent.silentSetupTitle,
        path: path(
          SettingsItemSection.wallet,
          isSpWalletSetup
              ? silent.silentSettingsTitle
              : silent.silentSetupTitle,
        ),
        icon: isSpWalletSetup ? Icons.currency_bitcoin : Icons.science,
        open: (context) =>
            SilentNavigation.openSettings(context, isSetUp: isSpWalletSetup),
        isSuperuser: true,
      ),
    SettingsItem(
      id: SettingsItemId.language,
      section: SettingsItemSection.app,
      title: localization.settingsLanguageTitle,
      path: path(SettingsItemSection.app, localization.settingsLanguageTitle),
      icon: Icons.language,
      open: (context) => context.pushNamed(SettingsRoute.appSettings.name),
      keywords: _keywords(
        localization.settingsSearchLanguageKeywords,
        english.settingsSearchLanguageKeywords,
        [english.settingsLanguageTitle],
      ),
      isInlineControl: true,
    ),
    SettingsItem(
      id: SettingsItemId.currency,
      section: SettingsItemSection.app,
      title: localization.settingsCurrencyTitle,
      path: path(SettingsItemSection.app, localization.settingsCurrencyTitle),
      icon: Icons.attach_money,
      open: (context) => context.pushNamed(SettingsRoute.appSettings.name),
      keywords: _keywords(
        localization.settingsSearchCurrencyKeywords,
        english.settingsSearchCurrencyKeywords,
        [english.settingsCurrencyTitle],
      ),
      isInlineControl: true,
    ),
    SettingsItem(
      id: SettingsItemId.quickActions,
      section: SettingsItemSection.app,
      title: localization.quickActionsSettingsTitle,
      path: path(
        SettingsItemSection.app,
        localization.quickActionsSettingsTitle,
      ),
      icon: Icons.tune,
      open: (context) => context.pushNamed(SettingsRoute.quickActions.name),
      keywords: [
        localization.quickActionsSettingsTitle,
        english.quickActionsSettingsTitle,
      ],
    ),
    SettingsItem(
      id: SettingsItemId.securityPin,
      section: SettingsItemSection.app,
      title: localization.settingsSecurityPinTitle,
      path: path(
        SettingsItemSection.app,
        localization.settingsSecurityPinTitle,
      ),
      icon: Icons.fiber_pin,
      open: (context) => const PinSettingsRouteData().push(context),
      keywords: _keywords(
        localization.settingsSearchSecurityPinKeywords,
        english.settingsSearchSecurityPinKeywords,
        [english.settingsSecurityPinTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.tor,
      section: SettingsItemSection.app,
      title: localization.torSettingsTitle,
      path: path(SettingsItemSection.app, localization.torSettingsTitle),
      icon: Icons.vpn_lock,
      open: (context) =>
          NetworkNavigation.open(context, section: NetworkSection.tor),
      keywords: _keywords(
        localization.settingsSearchTorKeywords,
        english.settingsSearchTorKeywords,
        [english.torSettingsTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.theme,
      section: SettingsItemSection.app,
      title: localization.settingsDarkModeTitle,
      path: path(SettingsItemSection.app, localization.settingsDarkModeTitle),
      icon: Icons.palette,
      open: (context) => context.pushNamed(SettingsRoute.appSettings.name),
      keywords: _keywords(
        localization.settingsSearchThemeKeywords,
        english.settingsSearchThemeKeywords,
        [
          localization.settingsThemeTitle,
          english.settingsThemeTitle,
          english.settingsDarkModeTitle,
        ],
      ),
      isInlineControl: true,
    ),
    SettingsItem(
      id: SettingsItemId.screenPrivacy,
      section: SettingsItemSection.app,
      title: localization.settingsScreenPrivacyTitle,
      path: path(
        SettingsItemSection.app,
        localization.settingsScreenPrivacyTitle,
      ),
      icon: Icons.screenshot_monitor,
      open: (context) => context.pushNamed(SettingsRoute.appSettings.name),
      keywords: _keywords(
        localization.settingsSearchScreenPrivacyKeywords,
        english.settingsSearchScreenPrivacyKeywords,
        [english.settingsScreenPrivacyTitle],
      ),
      isInlineControl: true,
    ),
    SettingsItem(
      id: SettingsItemId.errorReporting,
      section: SettingsItemSection.app,
      title: localization.settingsErrorReportingTitle,
      path: path(
        SettingsItemSection.app,
        localization.settingsErrorReportingTitle,
      ),
      icon: Icons.bug_report,
      open: (context) => context.pushNamed(SettingsRoute.appSettings.name),
      keywords: _keywords(
        localization.settingsSearchErrorReportingKeywords,
        english.settingsSearchErrorReportingKeywords,
        [english.settingsErrorReportingTitle],
      ),
      isInlineControl: true,
    ),
    if (backgroundTasksAvailable)
      SettingsItem(
        id: SettingsItemId.permissions,
        section: SettingsItemSection.app,
        title: localization.permissionsTitle,
        path: path(SettingsItemSection.app, localization.permissionsTitle),
        icon: Icons.verified_user_outlined,
        open: (context) => context.pushNamed(SettingsRoute.permissions.name),
        keywords: _keywords(
          localization.settingsSearchPermissionsKeywords,
          english.settingsSearchPermissionsKeywords,
          [english.permissionsTitle],
        ),
      ),
    if (isSuperuser)
      SettingsItem(
        id: SettingsItemId.devMode,
        section: SettingsItemSection.app,
        title: localization.appSettingsDevModeTitle,
        path: path(
          SettingsItemSection.app,
          localization.appSettingsDevModeTitle,
        ),
        icon: Icons.logo_dev,
        open: (context) => context.pushNamed(SettingsRoute.appSettings.name),
        keywords: _keywords(
          localization.settingsSearchDevModeKeywords,
          english.settingsSearchDevModeKeywords,
          [english.appSettingsDevModeTitle],
        ),
        isSuperuser: true,
        isInlineControl: true,
      ),
    if (isSuperuser && isDevModeEnabled)
      SettingsItem(
        id: SettingsItemId.testnetMode,
        section: SettingsItemSection.app,
        title: localization.networkSelectorTitle,
        path: path(SettingsItemSection.app, localization.networkSelectorTitle),
        icon: Icons.science,
        open: (context) => context.pushNamed(SettingsRoute.appSettings.name),
        keywords: _keywords(
          localization.settingsSearchTestnetModeKeywords,
          english.settingsSearchTestnetModeKeywords,
          [english.bitcoinSettingsTestnetModeTitle],
        ),
        isSuperuser: true,
        isInlineControl: true,
      ),
    if (kDebugMode && isDevModeEnabled)
      SettingsItem(
        id: SettingsItemId.arkDebugNotification,
        section: SettingsItemSection.app,
        title: localization.localeName.startsWith('fr')
            ? 'Tester la notification d’échéance Ark'
            : 'Test Ark expiry notification',
        path: path(SettingsItemSection.app, 'Ark notification'),
        icon: Icons.notifications_active_outlined,
        open: showArkDebugNotification,
      ),
    if (isDevModeEnabled)
      SettingsItem(
        id: SettingsItemId.testnetCredentials,
        section: SettingsItemSection.app,
        title: localization.exchangeTestnetBasicAuthTitle,
        path: path(
          SettingsItemSection.app,
          localization.exchangeTestnetBasicAuthTitle,
        ),
        icon: Icons.lock_outline,
        open: showExchangeTestnetBasicAuthDialog,
        keywords: _keywords(
          localization.settingsSearchTestnetCredentialsKeywords,
          english.settingsSearchTestnetCredentialsKeywords,
          [english.exchangeTestnetBasicAuthTitle],
        ),
      ),
  ].where((item) {
    final capability = switch (item.id) {
      SettingsItemId.exchange ||
      SettingsItemId.exchangeAccountSettings ||
      SettingsItemId.testnetCredentials => NetworkCapability.exchange,
      SettingsItemId.autoswap => NetworkCapability.automaticSwaps,
      SettingsItemId.payjoin => NetworkCapability.payjoin,
      SettingsItemId.ark => NetworkCapability.ark,
      SettingsItemId.sp => NetworkCapability.silentPayments,
      SettingsItemId.mempool ||
      SettingsItemId.feeSource ||
      SettingsItemId.servicesStatus => NetworkCapability.publicFeeEstimates,
      _ => null,
    };
    if (capability == null) return true;
    if (environment == null) return false;
    final network = switch (environment) {
      NetworkEnv.mainnet => BitcoinNetwork.mainnet,
      NetworkEnv.testnet => BitcoinNetwork.testnet,
      NetworkEnv.regtest => BitcoinNetwork.regtest,
      NetworkEnv.signet => BitcoinNetwork.signet,
    };
    return NetworkCapabilities.supports(network, capability);
  }).toList();
}

List<String> _keywords(
  String localized,
  String english,
  Iterable<String> englishFallbacks,
) => {...localized.split('|'), ...english.split('|'), ...englishFallbacks}
    .map((keyword) => keyword.trim())
    .where((keyword) => keyword.isNotEmpty)
    .toList();
