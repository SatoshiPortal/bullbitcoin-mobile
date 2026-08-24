import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/widgets/settings_search_view.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stays empty until typing, then shows the item and its path', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(home: SettingsSearchView(items: _items())),
    );
    await tester.pump();

    expect(find.text('Start typing to see results.'), findsOneWidget);
    expect(find.text('Tor Settings'), findsNothing);
    expect(find.text('Mempool Server'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'tor',
    );
    await tester.pump();

    expect(find.text('Start typing to see results.'), findsNothing);
    expect(find.text('Tor Settings'), findsOneWidget);
    expect(find.text('Settings → App Settings → Tor Settings'), findsOneWidget);
    expect(find.text('Mempool Server'), findsNothing);
  });

  testWidgets('reports when nothing matches', (tester) async {
    await tester.pumpWidget(
      _TestApp(home: SettingsSearchView(items: _items())),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'nothing here',
    );
    await tester.pump();

    expect(find.text('No settings found.'), findsOneWidget);
  });

  testWidgets('clearing the field returns to the empty state', (tester) async {
    await tester.pumpWidget(
      _TestApp(home: SettingsSearchView(items: _items())),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'tor',
    );
    await tester.pump();
    expect(find.text('Tor Settings'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-search-clear')));
    await tester.pump();

    expect(find.text('Tor Settings'), findsNothing);
    expect(find.text('Start typing to see results.'), findsOneWidget);
  });

  testWidgets('the clear button only exists while there is a query', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(home: SettingsSearchView(items: _items())),
    );
    await tester.pump();

    expect(find.byKey(const Key('settings-search-clear')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'tor',
    );
    await tester.pump();

    expect(find.byKey(const Key('settings-search-clear')), findsOneWidget);
  });

  testWidgets('a result opens over the search, which back returns to', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        home: SettingsSearchView(
          items: [
            SettingsItem(
              id: SettingsItemId.tor,
              section: SettingsItemSection.app,
              title: 'Tor Settings',
              path: const ['Settings', 'App Settings', 'Tor Settings'],
              icon: IconData(0),
              open: (context) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Tor')),
                    body: const Text('Tor Settings screen'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'tor',
    );
    await tester.pump();
    await tester.tap(find.text('Tor Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Tor Settings screen'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // The search survived the trip, query included: AOSP keeps the results
    // underneath the destination instead of dismissing them.
    expect(find.text('Tor Settings screen'), findsNothing);
    expect(find.text('Settings → App Settings → Tor Settings'), findsOneWidget);
  });

  testWidgets('uses a left-pointing breadcrumb in RTL locales', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        locale: const Locale('ar'),
        home: SettingsSearchView(
          items: [
            SettingsItem(
              id: SettingsItemId.tor,
              section: SettingsItemSection.app,
              title: 'إعدادات Tor',
              path: const ['الإعدادات', 'إعدادات التطبيق', 'إعدادات Tor'],
              icon: IconData(0),
              open: (_) {},
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'Tor',
    );
    await tester.pump();

    expect(
      find.text('الإعدادات ← إعدادات التطبيق ← إعدادات Tor'),
      findsOneWidget,
    );
  });
}

List<SettingsItem> _items() => [
  SettingsItem(
    id: SettingsItemId.tor,
    section: SettingsItemSection.app,
    title: 'Tor Settings',
    path: const ['Settings', 'App Settings', 'Tor Settings'],
    icon: IconData(0),
    open: (_) {},
  ),
  SettingsItem(
    id: SettingsItemId.mempool,
    section: SettingsItemSection.bitcoin,
    title: 'Mempool Server',
    path: const ['Settings', 'Bitcoin Settings', 'Mempool Server'],
    icon: IconData(0),
    open: (_) {},
  ),
];

class _TestApp extends StatelessWidget {
  final Widget home;
  final Locale? locale;

  const _TestApp({required this.home, this.locale});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: home,
    );
  }
}
