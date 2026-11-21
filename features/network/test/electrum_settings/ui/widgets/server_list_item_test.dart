import '../../../fixtures.dart';

import 'package:electrum/electrum.dart';
import 'package:network/src/electrum_settings/ui/widgets/server_list_item.dart';
import 'package:network/src/electrum_settings/presentation/electrum_server_view_model.dart';
import 'package:network/generated/l10n/network_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an unknown server as pending instead of offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: networkTestTheme(),
        localizationsDelegates: networkTestLocalizationsDelegates,
        supportedLocales: NetworkLocalizations.supportedLocales,
        home: const Scaffold(
          body: ServerListItem(
            server: ElectrumServerViewModel(
              network: ElectrumServerNetwork.bitcoinMainnet,
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
