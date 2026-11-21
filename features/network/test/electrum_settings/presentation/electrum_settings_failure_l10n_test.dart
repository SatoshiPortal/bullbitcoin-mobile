import 'package:network/src/electrum_settings/domain/electrum_settings_failure.dart';

import '../../fixtures.dart';

import 'package:network/src/electrum_settings/presentation/electrum_settings_failure_l10n.dart';
import 'package:network/generated/l10n/network_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('translates configured Tor failure without its raw detail', (
    tester,
  ) async {
    const failure = ElectrumServersExternalTorProxyUnavailableFailure(
      'secret detail',
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: networkTestLocalizationsDelegates,
        supportedLocales: NetworkLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Text(failure.toTranslated(context)),
        ),
      ),
    );

    final l10n = await NetworkLocalizations.delegate.load(const Locale('en'));
    expect(
      find.text(l10n.electrumConfiguredExternalTorUnavailable),
      findsOneWidget,
    );
    expect(find.text('secret detail'), findsNothing);
  });
}
