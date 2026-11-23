import 'package:exchange/exchange.dart';
import 'package:file_system/file_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../domain/usecases/get_account_info_usecase.dart';
import '../domain/usecases/get_exchange_preferences_usecase.dart';
import '../domain/usecases/get_exchange_statistics_usecase.dart';
import '../domain/usecases/get_secure_file_upload_status_usecase.dart';
import '../domain/usecases/update_exchange_preferences_usecase.dart';
import '../domain/usecases/upload_exchange_document_usecase.dart';
import '../presentation/account_info_cubit.dart';
import '../presentation/exchange_preferences_cubit.dart';
import '../presentation/secure_file_upload_cubit.dart';
import '../presentation/statistics_cubit.dart';
import 'exchange_settings_route.dart';
import 'screens/account_info_screen.dart';
import 'screens/exchange_preferences_screen.dart';
import 'screens/exchange_settings_screen.dart';
import 'screens/referrals_screen.dart';
import 'screens/secure_file_upload_screen.dart';
import 'screens/security_screen.dart';
import 'screens/statistics_screen.dart';

final class ExchangeSettingsHost {
  final Exchange Function() exchange;
  final SaveAccountPreferences savePreferences;
  final Future<void> Function(BuildContext) refreshSession;
  final bool Function(BuildContext) isLoggedIn;
  final Stream<bool> Function() sessionChanges;
  final bool Function(BuildContext) isSuperuser;
  final Uri? Function(BuildContext) securityUrl;
  final String Function(BuildContext) title;
  final String Function(BuildContext) signedOutMessage;
  final Widget Function(bool showDeleteAccount) buildAccountActions;
  final void Function(BuildContext) onOpenRecipients;
  final void Function(BuildContext) onOpenTransactions;
  final void Function(BuildContext) onOpenDefaultWallets;
  final void Function(BuildContext) onOpenExchange;

  const ExchangeSettingsHost({
    required this.exchange,
    required this.savePreferences,
    required this.refreshSession,
    required this.isLoggedIn,
    required this.sessionChanges,
    required this.isSuperuser,
    required this.securityUrl,
    required this.title,
    required this.signedOutMessage,
    required this.buildAccountActions,
    required this.onOpenRecipients,
    required this.onOpenTransactions,
    required this.onOpenDefaultWallets,
    required this.onOpenExchange,
  });
}

class ExchangeSettingsRouter {
  static List<RouteBase> routes(ExchangeSettingsHost config) => [
    GoRoute(
      name: ExchangeSettingsRoute.home.name,
      path: ExchangeSettingsRoute.home.path,
      builder: (context, state) => ExchangeSettingsScreen(
        isLoggedIn: () => config.isLoggedIn(context),
        sessionChanges: config.sessionChanges,
        isSuperuser: config.isSuperuser(context),
        title: config.title,
        signedOutMessage: config.signedOutMessage,
        buildAccountActions: config.buildAccountActions,
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
        create: (_) => ExchangePreferencesCubit(
          getExchangePreferencesUsecase: GetExchangePreferencesUsecase(
            exchange: config.exchange(),
          ),
          updateExchangePreferencesUsecase: UpdateExchangePreferencesUsecase(
            save: config.savePreferences,
          ),
        ),
        child: ExchangePreferencesScreen(refreshSession: config.refreshSession),
      ),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.secureFileUpload.name,
      path: ExchangeSettingsRoute.secureFileUpload.path,
      builder: (context, state) => BlocProvider(
        create: (_) => SecureFileUploadCubit(
          getUploadStatusUsecase: GetSecureFileUploadStatusUsecase(
            exchange: config.exchange(),
          ),
          uploadDocumentUsecase: UploadExchangeDocumentUsecase(
            fileSystem: const FileSystem.open(),
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
