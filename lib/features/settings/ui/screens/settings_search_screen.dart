import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/widgets/settings_search_view.dart';
import 'package:flutter/material.dart';

/// Full-screen settings search.
///
/// A screen rather than a sheet, and the destination is pushed on top of it
/// rather than replacing it, so going back from a result returns to the results
/// and a user who mistyped can try again without starting over.
class SettingsSearchScreen extends StatelessWidget {
  const SettingsSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ExchangeAccessBuilder(
      builder: (context, access) {
        final ready = ExchangeAvailability.canManageAccount(access);
        return SettingsSearchView(
          items: settingsItemsOf(context, accountReady: ready),
        );
      },
    );
  }
}
