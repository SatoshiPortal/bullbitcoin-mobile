import 'package:exchange/exchange.dart';
import 'package:file_system/file_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../default_wallets/default_wallets_payout_fields.dart';
import '../../default_wallets/ui/default_wallets_router.dart';
import '../../session/exchange_access_builder.dart';
import '../domain/usecases/get_account_info_usecase.dart';
import '../domain/usecases/get_exchange_preferences_usecase.dart';
import '../domain/usecases/get_exchange_statistics_usecase.dart';
import '../domain/usecases/get_secure_file_upload_status_usecase.dart';
import '../domain/usecases/update_exchange_preferences_usecase.dart';
import '../domain/usecases/pick_exchange_document_usecase.dart';
import '../domain/usecases/upload_exchange_document_usecase.dart';
import '../presentation/account_info_cubit.dart';
import '../presentation/exchange_preferences_bloc.dart';
import '../presentation/secure_file_upload_bloc.dart';
import '../presentation/statistics_cubit.dart';
import 'exchange_access_settings_route.dart';
import 'exchange_settings_route.dart';
import 'screens/account_info_screen.dart';
import 'screens/exchange_preferences_screen.dart';
import 'screens/exchange_settings_screen.dart';
import 'screens/referrals_screen.dart';
import 'screens/secure_file_upload_screen.dart';
import 'screens/security_screen.dart';
import 'screens/statistics_screen.dart';
import 'widgets/exchange_account_actions.dart';

final class ExchangeSettingsHost {
  final Exchange Function() exchange;
  final SaveAccountPreferences savePreferences;
  final Future<void> Function(BuildContext) refreshSession;
  final bool Function(BuildContext) isSuperuser;

  /// [ExchangePlatform.websiteOnly] for this device and the current user.
  bool websiteOnly(BuildContext context) =>
      ExchangePlatform.current.websiteOnly(isSuperuser: isSuperuser(context));
  final Uri? Function(BuildContext) securityUrl;
  final String Function(BuildContext) title;
  final String Function(BuildContext) signedOutMessage;
  final bool Function(BuildContext) hasAccount;
  final String Function(BuildContext, ExchangeFailure) accountFailureMessage;
  final void Function(BuildContext) onOpenRecipients;
  final void Function(BuildContext) onOpenTransactions;
  final void Function(BuildContext) onOpenDefaultWallets;
  final void Function(BuildContext) onOpenExchange;
  final ExchangeAccessSettingsHost? access;
  final DefaultWalletsHost? defaultWallets;

  const ExchangeSettingsHost({
    required this.exchange,
    required this.savePreferences,
    required this.refreshSession,
    required this.isSuperuser,
    required this.securityUrl,
    required this.title,
    required this.signedOutMessage,
    required this.hasAccount,
    required this.accountFailureMessage,
    required this.onOpenRecipients,
    required this.onOpenTransactions,
    required this.onOpenDefaultWallets,
    required this.onOpenExchange,
    this.access,
    this.defaultWallets,
  });
}

class ExchangeSettingsRouter {
  static List<RouteBase> routes(
    ExchangeSettingsHost config, {
    required DefaultWalletsPayoutFields payoutFields,
  }) => [
    if (config.defaultWallets case final host?)
      defaultWalletsRoute(config.exchange, host, payoutFields),
    if (config.access case final access?)
      exchangeAccessSettingsRoute(
        host: access,
        websiteOnly: config.websiteOnly,
        onOpenAccount: ExchangeSettingsRoute.home.open,
      ),
    GoRoute(
      name: ExchangeSettingsRoute.home.name,
      path: ExchangeSettingsRoute.home.path,
      builder: (context, state) => ExchangeSettingsScreen(
        isLoggedIn: () => exchangeSignedIn(config.exchange().currentAccess),
        sessionChanges: () =>
            config.exchange().watchAccess().map(exchangeSignedIn),
        websiteOnly: config.websiteOnly(context),
        title: config.title,
        signedOutMessage: config.signedOutMessage,
        buildAccountActions: (showDeleteAccount) => ExchangeAccountActions(
          showDeleteAccount: showDeleteAccount,
          exchange: config.exchange,
          failureMessage: config.accountFailureMessage,
          hasAccount: config.hasAccount,
        ),
        onOpenRecipients: () => config.onOpenRecipients(context),
        onOpenTransactions: () => config.onOpenTransactions(context),
        onOpenDefaultWallets: () => config.onOpenDefaultWallets(context),
        onOpenExchange: () => config.onOpenExchange(context),
      ),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.security.name,
      path: ExchangeSettingsRoute.security.path,
      builder: (context, state) => Builder(
        builder: (context) =>
            ExchangeSecurityScreen(securityUrl: config.securityUrl(context)),
      ),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.referrals.name,
      path: ExchangeSettingsRoute.referrals.path,
      builder: (context, state) => const ExchangeReferralsScreen(),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.accountInfo.name,
      path: ExchangeSettingsRoute.accountInfo.path,
      builder: (context, state) => BlocProvider(
        create: (_) => AccountInfoCubit(
          getAccountInfoUsecase: GetAccountInfoUsecase(
            exchange: config.exchange(),
          ),
        ),
        child: const AccountInfoScreen(),
      ),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.preferences.name,
      path: ExchangeSettingsRoute.preferences.path,
      builder: (context, state) => BlocProvider(
        create: (_) {
          final exchange = config.exchange();
          return ExchangePreferencesBloc(
            session: exchange.currentSession,
            getPreferences: GetExchangePreferencesUsecase(exchange: exchange),
            updatePreferences: UpdateExchangePreferencesUsecase(
              save: config.savePreferences,
              writeGate: exchange.writeGate,
            ),
          );
        },
        child: ExchangePreferencesScreen(refreshSession: config.refreshSession),
      ),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.secureFileUpload.name,
      path: ExchangeSettingsRoute.secureFileUpload.path,
      builder: (context, state) => BlocProvider(
        create: (_) => SecureUploadBloc(
          getUploadStatus: GetSecureFileUploadStatusUsecase(
            exchange: config.exchange(),
          ),
          pickDocument: const PickExchangeDocumentUsecase(
            fileSystem: FileSystem.open(),
          ),
          uploadDocument: UploadExchangeDocumentUsecase(
            exchange: config.exchange(),
          ),
        ),
        child: const SecureFileUploadScreen(),
      ),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.statistics.name,
      path: ExchangeSettingsRoute.statistics.path,
      builder: (context, state) => BlocProvider(
        create: (_) => StatisticsCubit(
          getStatisticsUsecase: GetExchangeStatisticsUsecase(
            exchange: config.exchange(),
          ),
        ),
        child: const StatisticsScreen(),
      ),
    ),
  ];
}
