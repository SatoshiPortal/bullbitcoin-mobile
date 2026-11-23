import 'package:exchange/exchange.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:settings/settings.dart';

import 'settings_item.dart';

/// Projects the catalogue shared with the Settings screens still in the app.
abstract final class SettingsHubBindings {
  static Widget menuScope(Widget child) => ExchangeAccessBuilder(
    builder: (_, access) =>
        RepositoryProvider<ExchangeAccess>.value(value: access, child: child),
  );

  static SettingsMenu menuOf(BuildContext context) {
    final access = context.watch<ExchangeAccess>();
    final items = settingsItemsOf(
      context,
      accountReady: ExchangeAvailability.canManageAccount(access),
    );
    return (
      entries: [
        for (final item in items)
          item.hubEntry(homeIcon: item.assetIcon(context)),
      ],
      appVersion: context.select(
        (SettingsCubit cubit) => cubit.state.appVersion,
      ),
    );
  }

  static SettingsLabels labelsOf(BuildContext context) => (
    title: context.loc.settingsScreenTitle,
    searchHint: context.loc.settingsSearchHint,
    searchStartTyping: context.loc.settingsSearchStartTyping,
    searchNoResults: context.loc.settingsSearchNoResults,
    appVersionLabel: context.loc.settingsAppVersionLabel,
  );
}
