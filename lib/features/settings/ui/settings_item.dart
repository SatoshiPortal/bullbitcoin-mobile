import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/bip85_entropy/router.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/import_wallet/router.dart';
import 'package:bb_mobile/features/labels/router.dart';
import 'package:bb_mobile/features/mempool_settings/router.dart';
import 'package:bb_mobile/features/recoverbull/public/recoverbull_facade.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_route.dart';
import 'package:bb_mobile/features/settings/ui/widgets/exchange_testnet_basic_auth_dialog.dart';
import 'package:bb_mobile/features/status_check/router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

enum SettingsItemId {
  exchange,
  backup,
  startBackup,
  recoverbull,
  labels,
  transactionHistory,
  walletSettings,
  appSettings,
  btcMap,
  termsOfService,
  servicesStatus,
  importWallet,
  signingKeyExport,
  broadcastTransaction,
  payjoin,
  autoswap,
  electrum,
  mempool,
  testnetMode,
  seedViewer,
  bip85,
  language,
  theme,
  currency,
  securityPin,
  logs,
  screenPrivacy,
  devMode,
  testnetCredentials,
  errorReporting,
}

enum SettingsItemSection { root, backup, wallet, app }

const backupSettingsDataItemOrder = [
  SettingsItemId.labels,
  SettingsItemId.transactionHistory,
];

const walletSettingsItemOrder = [
  SettingsItemId.payjoin,
  SettingsItemId.autoswap,
  SettingsItemId.importWallet,
  SettingsItemId.electrum,
  SettingsItemId.mempool,
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
  }) : _open = open; // ignore: prefer_initializing_formals

  String location(TextDirection textDirection) =>
      path.join(textDirection == TextDirection.rtl ? ' ← ' : ' → ');

  void open(BuildContext context) => _open(context);

  Widget buildTile(
    BuildContext context, {
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
  }) {
    return SettingsEntryItem(
      icon: icon,
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
List<SettingsItem> settingsItemsOf(BuildContext context) {
  final isSuperuser = context.select(
    (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
  );
  final isDevModeEnabled = context.select(
    (SettingsCubit cubit) => cubit.state.isDevModeEnabled ?? false,
  );

  return buildSettingsItems(
    localization: context.loc,
    isSuperuser: isSuperuser,
    isDevModeEnabled: isDevModeEnabled,
  );
}

List<SettingsItem> buildSettingsItems({
  required AppLocalizations localization,
  bool isSuperuser = false,
  bool isDevModeEnabled = false,
}) {
  final english = AppLocalizationsEn();
  final rootSection = localization.settingsScreenTitle;
  final backupSection = localization.settingsBackupTitle;
  final walletSection = localization.settingsWalletTitle;
  final appSection = localization.settingsAppTitle;
  final exchangeSection = localization.settingsExchangeTitle;

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
      open: (context) => context.pushNamed(SettingsRoute.backupSettings.name),
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
      open: (context) => context.pushNamed(
        BackupSettingsSubroute.backupOptions.name,
        extra: BackupSettingsFlow.backup,
      ),
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
      open: (context) => const RecoverBullFacade().openSettings(context),
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
      open: (context) => context.push(LabelsRouter.route.path),
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
      open: (context) =>
          context.pushNamed(TransactionsRoute.exportTransactions.name),
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
      title: exchangeSection,
      path: path(SettingsItemSection.root, exchangeSection),
      icon: Icons.currency_exchange,
      open: (context) {
        final notLoggedIn = context.read<ExchangeCubit>().state.notLoggedIn;
        if (notLoggedIn) {
          context.goNamed(ExchangeRoute.exchangeLanding.name);
        } else {
          context.pushNamed(SettingsRoute.exchangeSettings.name);
        }
      },
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
    SettingsItem(
      id: SettingsItemId.btcMap,
      section: SettingsItemSection.root,
      title: localization.settingsBtcMapTitle,
      path: path(SettingsItemSection.root, localization.settingsBtcMapTitle),
      icon: Icons.map,
      open: (context) => context.pushNamed(SettingsRoute.btcMap.name),
      keywords: _keywords(
        localization.settingsSearchBtcMapKeywords,
        english.settingsSearchBtcMapKeywords,
        [english.settingsBtcMapTitle],
      ),
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
        Uri.parse(SettingsConstants.termsAndConditionsLink),
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
      open: (context) => context.pushNamed(StatusCheckRoute.serviceStatus.name),
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
      id: SettingsItemId.importWallet,
      section: SettingsItemSection.wallet,
      title: localization.walletSettingsImportWalletTitle,
      path: path(
        SettingsItemSection.wallet,
        localization.walletSettingsImportWalletTitle,
      ),
      icon: Icons.sim_card_download,
      open: (context) =>
          context.pushNamed(ImportWalletRoute.importWalletHome.name),
      keywords: _keywords(
        localization.settingsSearchImportWalletKeywords,
        english.settingsSearchImportWalletKeywords,
        [english.walletSettingsImportWalletTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.signingKeyExport,
      section: SettingsItemSection.wallet,
      title: localization.signingKeyExportTitle,
      path: path(
        SettingsItemSection.wallet,
        localization.signingKeyExportTitle,
      ),
      icon: Icons.key,
      open: (context) => context.pushNamed(SettingsRoute.signingKeyExport.name),
      keywords: _keywords(
        localization.settingsSearchSigningKeyExportKeywords,
        english.settingsSearchSigningKeyExportKeywords,
        [english.signingKeyExportTitle],
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
      open: (context) => context.pushNamed(SettingsRoute.autoswapSettings.name),
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
      id: SettingsItemId.electrum,
      section: SettingsItemSection.wallet,
      title: localization.bitcoinSettingsElectrumServerTitle,
      path: path(
        SettingsItemSection.wallet,
        localization.bitcoinSettingsElectrumServerTitle,
      ),
      icon: Icons.hub,
      open: (context) =>
          context.pushNamed(ElectrumSettingsRoute.electrumSettings.name),
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
      open: (context) => context.pushNamed(MempoolSettingsRoute.name),
      keywords: _keywords(
        localization.settingsSearchMempoolKeywords,
        english.settingsSearchMempoolKeywords,
        [english.bitcoinSettingsMempoolServerTitle],
      ),
    ),
    if (isSuperuser)
      SettingsItem(
        id: SettingsItemId.seedViewer,
        section: SettingsItemSection.wallet,
        title: localization.allSeedViewTitle,
        path: path(SettingsItemSection.wallet, localization.allSeedViewTitle),
        icon: Icons.vpn_key,
        open: (context) => context.pushNamed(SettingsRoute.allSeedView.name),
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
        open: (context) => context.pushNamed(Bip85EntropyRoute.bip85Home.name),
        keywords: _keywords(
          localization.settingsSearchBip85Keywords,
          english.settingsSearchBip85Keywords,
          [english.bitcoinSettingsBip85EntropiesTitle],
        ),
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
      id: SettingsItemId.theme,
      section: SettingsItemSection.app,
      title: localization.settingsThemeTitle,
      path: path(SettingsItemSection.app, localization.settingsThemeTitle),
      icon: Icons.palette,
      open: (context) => context.pushNamed(SettingsRoute.theme.name),
      keywords: _keywords(
        localization.settingsSearchThemeKeywords,
        english.settingsSearchThemeKeywords,
        [english.settingsThemeTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.currency,
      section: SettingsItemSection.app,
      title: localization.settingsCurrencyTitle,
      path: path(SettingsItemSection.app, localization.settingsCurrencyTitle),
      icon: Icons.attach_money,
      open: (context) => context.pushNamed(SettingsRoute.currency.name),
      keywords: _keywords(
        localization.settingsSearchCurrencyKeywords,
        english.settingsSearchCurrencyKeywords,
        [english.settingsCurrencyTitle],
      ),
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
      open: (context) => context.pushNamed(SettingsRoute.pinCode.name),
      keywords: _keywords(
        localization.settingsSearchSecurityPinKeywords,
        english.settingsSearchSecurityPinKeywords,
        [english.settingsSecurityPinTitle],
      ),
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
        title: localization.bitcoinSettingsTestnetModeTitle,
        path: path(
          SettingsItemSection.app,
          localization.bitcoinSettingsTestnetModeTitle,
        ),
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
  ];
}

List<String> _keywords(
  String localized,
  String english,
  Iterable<String> englishFallbacks,
) => {...localized.split('|'), ...english.split('|'), ...englishFallbacks}
    .map((keyword) => keyword.trim())
    .where((keyword) => keyword.isNotEmpty)
    .toList();
