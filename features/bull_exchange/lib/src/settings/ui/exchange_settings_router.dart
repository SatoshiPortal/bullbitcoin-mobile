import 'package:exchange/exchange.dart';
import 'package:file_system/file_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../../default_wallets/default_wallets_payout_fields.dart';
import '../../default_wallets/ui/default_wallets_router.dart';
import '../../exchange_failure_l10n.dart';
import '../../exchange_landing_navigation.dart';
import '../../session/exchange_access_builder.dart';
import '../../session/exchange_session_scope.dart';
import '../domain/usecases/get_account_info_usecase.dart';
import '../domain/usecases/get_exchange_preferences_usecase.dart';
import '../domain/usecases/get_exchange_statistics_usecase.dart';
import '../domain/usecases/get_secure_file_upload_status_usecase.dart';
import '../domain/usecases/update_exchange_preferences_usecase.dart';
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
  final NetworkEnv? Function(BuildContext) networkOf;
  final bool Function(BuildContext) isSuperuser;
  final String Function(BuildContext) title;
  final String Function(BuildContext) signedOutMessage;
  final void Function(BuildContext) onOpenRecipients;
  final void Function(BuildContext) onOpenTransactions;
  final String Function(BuildContext)? accessDescription;
  final bool includeDefaultWallets;

  const ExchangeSettingsHost({
    required this.networkOf,
    required this.isSuperuser,
    required this.title,
    required this.signedOutMessage,
    required this.onOpenRecipients,
    required this.onOpenTransactions,
    this.accessDescription,
    this.includeDefaultWallets = false,
  });

  bool _websiteOnly(BuildContext context) =>
      ExchangePlatform.current.websiteOnly(isSuperuser: isSuperuser(context));
}

class ExchangeSettingsRouter {
  static List<RouteBase> routes(
    ExchangeSettingsHost config, {
    required Exchange Function() exchange,
    required Preferences Function() preferences,
    required String homePath,
    required void Function(BuildContext) onExit,
    required DefaultWalletsPayoutFields payoutFields,
  }) => [
    if (config.includeDefaultWallets)
      defaultWalletsRoute(exchange, (
        isAvailable: () async => switch (await preferences().fetch()) {
          Ok(:final value) => NetworkCapabilities.supports(
            BitcoinNetwork.fromName(value.environment.name),
            NetworkCapability.exchange,
          ),
          Err() => false,
        },
        unavailableRedirectPath: homePath,
      ), payoutFields),
    if (config.accessDescription case final description?)
      exchangeAccessSettingsRoute(
        host: (
          actions: (
            current: () => exchange().currentAccess,
            watch: () => exchange().watchAccess(),
            enable: () => exchange().enableAccess(),
            signOut: () => exchange().signOut(),
            resolve: () => exchange().resolveAccess(),
          ),
          description: description,
          onAuthenticate: (context) => context.pushNamed<void>(
            BullExchangeNavigation.authName,
            queryParameters: {'from': 'settings'},
          ),
          onDisabled: onExit,
        ),
        websiteOnly: config._websiteOnly,
        onOpenAccount: ExchangeSettingsRoute.home.open,
      ),
    GoRoute(
      name: ExchangeSettingsRoute.home.name,
      path: ExchangeSettingsRoute.home.path,
      builder: (context, state) => ExchangeSettingsScreen(
        isLoggedIn: () => exchangeSignedIn(exchange().currentAccess),
        sessionChanges: () => exchange().watchAccess().map(exchangeSignedIn),
        websiteOnly: config._websiteOnly(context),
        title: config.title,
        signedOutMessage: config.signedOutMessage,
        buildAccountActions: (showDeleteAccount) => ExchangeAccountActions(
          showDeleteAccount: showDeleteAccount,
          exchange: exchange,
          failureMessage: (context, failure) => failure.toTranslated(context),
          hasAccount: ExchangeSessionScope.watchHasAccount,
        ),
        onOpenRecipients: () => config.onOpenRecipients(context),
        onOpenTransactions: () => config.onOpenTransactions(context),
        onOpenDefaultWallets: () => DefaultWalletsNavigation.open(context),
        onOpenExchange: () => BullExchangeNavigation.goToDashboard(context),
      ),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.security.name,
      path: ExchangeSettingsRoute.security.path,
      builder: (context, state) => Builder(
        builder: (context) => ExchangeSecurityScreen(
          securityUrl: switch (config.networkOf(context)) {
            NetworkEnv.mainnet => Uri.parse(
              ExchangeDefaults.bbAuthUrl,
            ).resolve('/settings'),
            NetworkEnv.testnet => Uri.parse(
              ExchangeDefaults.bbAuthTestUrl,
            ).resolve('/settings'),
            null || NetworkEnv.regtest || NetworkEnv.signet => null,
          },
        ),
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
          getAccountInfoUsecase: GetAccountInfoUsecase(exchange: exchange()),
        ),
        child: const AccountInfoScreen(),
      ),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.preferences.name,
      path: ExchangeSettingsRoute.preferences.path,
      builder: (context, state) => BlocProvider(
        create: (_) {
          final owner = exchange();
          return ExchangePreferencesBloc(
            getExchangePreferencesUsecase: GetExchangePreferencesUsecase(
              exchange: owner,
            ),
            updateExchangePreferencesUsecase: UpdateExchangePreferencesUsecase(
              save: (patch) => exchange().updateCurrentPreferences(patch),
            ),
            writeGate: owner.writeGate,
            session: owner.currentSession,
          );
        },
        child: ExchangePreferencesScreen(
          refreshSession: ExchangeSessionScope.refresh,
        ),
      ),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.secureFileUpload.name,
      path: ExchangeSettingsRoute.secureFileUpload.path,
      builder: (context, state) => BlocProvider(
        create: (_) => SecureUploadBloc(
          getUploadStatusUsecase: GetSecureFileUploadStatusUsecase(
            exchange: exchange(),
          ),
          uploadDocumentUsecase: UploadExchangeDocumentUsecase(
            fileSystem: const FileSystem.open(),
            exchange: exchange(),
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
            exchange: exchange(),
          ),
        ),
        child: const StatisticsScreen(),
      ),
    ),
  ];
}
