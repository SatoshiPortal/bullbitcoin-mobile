import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/screen_privacy_gate.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host extends StatefulWidget {
  const _Host(this.answers);

  final List<bool> answers;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var _calls = 0;
  late Future<bool> _protection = _ask();

  Future<bool> _ask() async => widget.answers[_calls++];

  @override
  Widget build(BuildContext context) => ScreenPrivacyGate(
    protection: _protection,
    onRetry: () => setState(() {
      _protection = _ask();
    }),
    builder: (context) => const Text('the secret'),
  );
}

void main() {
  Future<void> pump(WidgetTester tester, List<bool> answers) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _Host(answers),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('draws the secret once capture blocking is confirmed', (
    tester,
  ) async {
    await pump(tester, [true]);

    expect(find.text('the secret'), findsOneWidget);
  });

  testWidgets('hides the secret when the platform refused, until a retry '
      'succeeds', (tester) async {
    await pump(tester, [false, true]);

    expect(find.text('the secret'), findsNothing);
    final context = tester.element(find.byType(ScreenPrivacyGate));
    expect(
      find.text(AppLocalizations.of(context).screenPrivacyUnavailable),
      findsOneWidget,
    );

    await tester.tap(find.text(AppLocalizations.of(context).retry));
    await tester.pumpAndSettle();

    expect(find.text('the secret'), findsOneWidget);
  });
}
