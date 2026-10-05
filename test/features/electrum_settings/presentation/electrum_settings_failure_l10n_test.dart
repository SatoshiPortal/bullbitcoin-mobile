import 'package:bb_mobile/features/electrum_settings/domain/electrum_settings_failure.dart';
import 'package:bb_mobile/features/electrum_settings/presentation/electrum_settings_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Text(failure.toTranslated(context)),
        ),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      find.text(l10n.electrumConfiguredExternalTorUnavailable),
      findsOneWidget,
    );
    expect(find.text('secret detail'), findsNothing);
  });
}
