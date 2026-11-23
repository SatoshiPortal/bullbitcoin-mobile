import 'package:exchange/exchange.dart';
import 'package:settings/src/l10n.dart';
import 'package:settings/src/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../settings_menu.dart';

import 'settings_item.dart';

/// Projects the catalogue shared by the Settings screens and search.
abstract final class SettingsHubBindings {
  static SettingsMenu menuOf(BuildContext context) {
    final access = context.watch<ExchangeAccess?>();
    final items = settingsItemsOf(
      context,
      accountReady:
          access != null && ExchangeAvailability.canManageAccount(access),
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
