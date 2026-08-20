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
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/features/settings/ui/settings_route.dart';
import 'package:bb_mobile/features/settings/ui/widgets/exchange_testnet_basic_auth_dialog.dart';
import 'package:bb_mobile/features/status_check/router.dart';
import 'package:bb_mobile/features/tor_settings/ui/tor_settings_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

enum SettingsItemId {
  exchange,
  walletBackup,
  startBackup,
  recoverbull,
  labels,
  transactionHistory,
  bitcoinSettings,
  appSettings,
  btcMap,
  termsOfService,
  servicesStatus,
  wallets,
  importWallet,
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
  tor,
  logs,
  screenPrivacy,
  devMode,
  testnetCredentials,
  errorReporting,
}

enum SettingsItemSection { root, walletBackup, bitcoin, app }

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

List<SettingsItem> buildSettingsItems({
  required AppLocalizations localization,
  required String exchangeTitle,
  bool isSuperuser = false,
  bool isDevModeEnabled = false,
}) {
  final english = AppLocalizationsEn();
  final rootSection = localization.settingsScreenTitle;
  final backupSection = localization.settingsWalletBackupTitle;
  final bitcoinSection = localization.settingsBitcoinSettingsTitle;
  final appSection = localization.settingsAppSettingsTitle;

  List<String> path(SettingsItemSection section, String title) =>
      switch (section) {
        SettingsItemSection.root => [rootSection, title],
        SettingsItemSection.walletBackup => [rootSection, backupSection, title],
        SettingsItemSection.bitcoin => [rootSection, bitcoinSection, title],
        SettingsItemSection.app => [rootSection, appSection, title],
      };

  return [
    SettingsItem(
      id: SettingsItemId.exchange,
      section: SettingsItemSection.root,
      title: exchangeTitle,
      path: path(SettingsItemSection.root, exchangeTitle),
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
          english.settingsExchangeSettingsTitle,
          english.settingsAccountSettingsTitle,
        ],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.walletBackup,
      section: SettingsItemSection.root,
      title: backupSection,
      path: path(SettingsItemSection.root, backupSection),
      icon: Icons.save,
      open: (context) => context.pushNamed(SettingsRoute.backupSettings.name),
      keywords: _keywords(
        localization.settingsSearchWalletBackupKeywords,
        english.settingsSearchWalletBackupKeywords,
        [english.settingsWalletBackupTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.startBackup,
      section: SettingsItemSection.walletBackup,
      title: localization.backupSettingsStartBackup,
      path: path(
        SettingsItemSection.walletBackup,
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
      section: SettingsItemSection.walletBackup,
      title: localization.backupSettingsRecoverBullSettings,
      path: path(
        SettingsItemSection.walletBackup,
        localization.backupSettingsRecoverBullSettings,
      ),
      icon: Icons.cloud_circle,
      open: (context) => context.pushNamed(
        RecoverBullRoute.recoverbullFlows.name,
        extra: RecoverBullFlowsExtra(
          flow: RecoverBullFlow.settings,
          vault: null,
        ),
      ),
      keywords: _keywords(
        localization.settingsSearchRecoverbullKeywords,
        english.settingsSearchRecoverbullKeywords,
        [english.backupSettingsRecoverBullSettings],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.labels,
      section: SettingsItemSection.walletBackup,
      title: localization.backupSettingsLabelsButton,
      path: path(
        SettingsItemSection.walletBackup,
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
      section: SettingsItemSection.walletBackup,
      title: localization.transactionHistoryTitle,
      path: path(
        SettingsItemSection.walletBackup,
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
      id: SettingsItemId.bitcoinSettings,
      section: SettingsItemSection.root,
      title: bitcoinSection,
      path: path(SettingsItemSection.root, bitcoinSection),
      icon: Icons.currency_bitcoin,
      open: (context) => context.pushNamed(SettingsRoute.bitcoinSettings.name),
      keywords: _keywords(
        localization.settingsSearchBitcoinSettingsKeywords,
        english.settingsSearchBitcoinSettingsKeywords,
        [english.settingsBitcoinSettingsTitle],
      ),
    ),
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
        [english.settingsAppSettingsTitle],
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
      title: localization.settingsServicesStatusTitle,
      path: path(
        SettingsItemSection.root,
        localization.settingsServicesStatusTitle,
      ),
      icon: Icons.monitor_heart,
      open: (context) => context.pushNamed(StatusCheckRoute.serviceStatus.name),
      keywords: _keywords(
        localization.settingsSearchServicesStatusKeywords,
        english.settingsSearchServicesStatusKeywords,
        [english.settingsServicesStatusTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.wallets,
      section: SettingsItemSection.bitcoin,
      title: localization.bitcoinSettingsWalletsTitle,
      path: path(
        SettingsItemSection.bitcoin,
        localization.bitcoinSettingsWalletsTitle,
      ),
      icon: Icons.account_balance_wallet,
      open: (context) =>
          context.pushNamed(SettingsRoute.walletDetailsWalletList.name),
      keywords: _keywords(
        localization.settingsSearchWalletsKeywords,
        english.settingsSearchWalletsKeywords,
        [english.bitcoinSettingsWalletsTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.importWallet,
      section: SettingsItemSection.bitcoin,
      title: localization.bitcoinSettingsImportWalletTitle,
      path: path(
        SettingsItemSection.bitcoin,
        localization.bitcoinSettingsImportWalletTitle,
      ),
      icon: Icons.sim_card_download,
      open: (context) =>
          context.pushNamed(ImportWalletRoute.importWalletHome.name),
      keywords: _keywords(
        localization.settingsSearchImportWalletKeywords,
        english.settingsSearchImportWalletKeywords,
        [english.bitcoinSettingsImportWalletTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.broadcastTransaction,
      section: SettingsItemSection.bitcoin,
      title: localization.bitcoinSettingsBroadcastTransactionTitle,
      path: path(
        SettingsItemSection.bitcoin,
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
      section: SettingsItemSection.bitcoin,
      title: localization.bitcoinSettingsPayjoinTitle,
      path: path(
        SettingsItemSection.bitcoin,
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
      section: SettingsItemSection.bitcoin,
      title: localization.autoswapSettingsTitle,
      path: path(
        SettingsItemSection.bitcoin,
        localization.autoswapSettingsTitle,
      ),
      icon: Icons.swap_vertical_circle,
      open: (context) => context.pushNamed(SettingsRoute.autoswapSettings.name),
      keywords: _keywords(
        localization.settingsSearchAutoswapKeywords,
        english.settingsSearchAutoswapKeywords,
        [english.autoswapSettingsTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.electrum,
      section: SettingsItemSection.bitcoin,
      title: localization.bitcoinSettingsElectrumServerTitle,
      path: path(
        SettingsItemSection.bitcoin,
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
      section: SettingsItemSection.bitcoin,
      title: localization.bitcoinSettingsMempoolServerTitle,
      path: path(
        SettingsItemSection.bitcoin,
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
    if (isSuperuser && isDevModeEnabled)
      SettingsItem(
        id: SettingsItemId.testnetMode,
        section: SettingsItemSection.bitcoin,
        title: localization.bitcoinSettingsTestnetModeTitle,
        path: path(
          SettingsItemSection.bitcoin,
          localization.bitcoinSettingsTestnetModeTitle,
        ),
        icon: Icons.science,
        open: (context) =>
            context.pushNamed(SettingsRoute.bitcoinSettings.name),
        keywords: _keywords(
          localization.settingsSearchTestnetModeKeywords,
          english.settingsSearchTestnetModeKeywords,
          [english.bitcoinSettingsTestnetModeTitle],
        ),
        isSuperuser: true,
        isInlineControl: true,
      ),
    if (isSuperuser)
      SettingsItem(
        id: SettingsItemId.seedViewer,
        section: SettingsItemSection.bitcoin,
        title: localization.allSeedViewTitle,
        path: path(SettingsItemSection.bitcoin, localization.allSeedViewTitle),
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
        section: SettingsItemSection.bitcoin,
        title: localization.bitcoinSettingsBip85EntropiesTitle,
        path: path(
          SettingsItemSection.bitcoin,
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
      id: SettingsItemId.tor,
      section: SettingsItemSection.app,
      title: localization.settingsTorSettingsTitle,
      path: path(
        SettingsItemSection.app,
        localization.settingsTorSettingsTitle,
      ),
      icon: Icons.vpn_lock,
      open: (context) => context.pushNamed(TorSettingsRoute.torSettings.name),
      keywords: _keywords(
        localization.settingsSearchTorKeywords,
        english.settingsSearchTorKeywords,
        [english.settingsTorSettingsTitle],
      ),
    ),
    SettingsItem(
      id: SettingsItemId.logs,
      section: SettingsItemSection.app,
      title: localization.logSettingsLogsTitle,
      path: path(SettingsItemSection.app, localization.logSettingsLogsTitle),
      icon: Icons.article,
      open: (context) => context.pushNamed(SettingsRoute.logs.name),
      keywords: _keywords(
        localization.settingsSearchLogsKeywords,
        english.settingsSearchLogsKeywords,
        [english.logSettingsLogsTitle],
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
