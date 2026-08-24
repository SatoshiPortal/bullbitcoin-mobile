import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/ui/widgets/settings_search_bar.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the search label', (tester) async {
    await tester.pumpWidget(_TestApp(child: SettingsSearchBar(onTap: () {})));

    expect(find.text('Search settings'), findsOneWidget);
  });

  testWidgets('calls back when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _TestApp(child: SettingsSearchBar(onTap: () => taps++)),
    );

    await tester.tap(find.byType(SettingsSearchBar));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('holds no editable field, so tapping cannot raise a keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(_TestApp(child: SettingsSearchBar(onTap: () {})));

    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('reports itself to assistive tech as one labelled button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_TestApp(child: SettingsSearchBar(onTap: () {})));

    final node = tester.getSemantics(find.byType(SettingsSearchBar));

    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isTextField, isFalse);
    expect(node.label, 'Search settings');

    handle.dispose();
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }
}
