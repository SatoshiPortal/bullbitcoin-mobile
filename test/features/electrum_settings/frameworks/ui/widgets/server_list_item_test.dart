import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/server_list_item.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/view_models/electrum_server_view_model.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an unknown server as pending instead of offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: ServerListItem(
            server: ElectrumServerViewModel(
              url: 'ssl://electrum.example.com:50002',
              status: ElectrumServerStatus.unknown,
              priority: 0,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('Offline'), findsNothing);
  });
}
