import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../domain/manage_exchange_access_usecase.dart';
import '../presentation/exchange_access_settings_bloc.dart';
import 'screens/exchange_access_settings_screen.dart';

/// Navigation to the exchange access controls nested under app settings.
abstract final class ExchangeAccessSettingsNavigation {
  static const name = 'exchangeAccess';
  static const path = 'exchange-access';

  static Future<void> open(BuildContext context) =>
      context.pushNamed<void>(name);
}

typedef ExchangeAccessSettingsHost = ({
  ExchangeAccessActions actions,
  String Function(BuildContext) description,
  Future<void> Function(BuildContext) onAuthenticate,
  void Function(BuildContext) onDisabled,
});

GoRoute exchangeAccessSettingsRoute({
  required ExchangeAccessSettingsHost host,
  required bool Function(BuildContext) websiteOnly,
  required void Function(BuildContext) onOpenAccount,
}) => GoRoute(
  name: ExchangeAccessSettingsNavigation.name,
  path: ExchangeAccessSettingsNavigation.path,
  builder: (context, state) => BlocProvider(
    create: (_) => ExchangeAccessSettingsBloc(
      WatchExchangeAccessUsecase(host.actions),
      ManageExchangeAccessUsecase(host.actions),
    ),
    child: Builder(
      builder: (context) => ExchangeAccessSettingsScreen(
        description: host.description(context),
        activationAllowed: !websiteOnly(context),
        onBack: () => context.pop(),
        onAuthenticate: () => host.onAuthenticate(context),
        onOpenAccount: () => onOpenAccount(context),
        onDisabled: () => host.onDisabled(context),
      ),
    ),
  ),
);
