import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/widgets/settings_search_sheet.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stays empty until typing then shows matching item and path', (
    tester,
  ) async {
    await tester.pumpWidget(_TestApp(home: _EmbeddedSearch(items: _items())));
    await tester.pump();

    expect(find.text('Tor Settings'), findsNothing);
    expect(find.text('Mempool Server'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'tor',
    );
    await tester.pump();

    expect(find.byTooltip('Clear text'), findsOneWidget);
    expect(find.text('Tor Settings'), findsOneWidget);
    expect(find.text('Settings → App Settings → Tor Settings'), findsOneWidget);
    expect(find.text('Mempool Server'), findsNothing);
  });

  testWidgets('returns the shared item when a result is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(_TestApp(home: _SearchLauncher(items: _items())));

    await tester.tap(find.text('Open search'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'tor',
    );
    await tester.pump();
    await tester.tap(find.text('Tor Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Selected: tor'), findsOneWidget);
  });

  testWidgets('uses a left-pointing breadcrumb in RTL locales', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        locale: const Locale('ar'),
        home: _EmbeddedSearch(
          items: [
            SettingsItem(
              id: SettingsItemId.tor,
              section: SettingsItemSection.app,
              title: 'إعدادات Tor',
              path: const ['الإعدادات', 'إعدادات التطبيق', 'إعدادات Tor'],
              icon: Icons.vpn_lock,
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
    icon: Icons.vpn_lock,
    open: (_) {},
  ),
  SettingsItem(
    id: SettingsItemId.mempool,
    section: SettingsItemSection.bitcoin,
    title: 'Mempool Server',
    path: const ['Settings', 'Bitcoin Settings', 'Mempool Server'],
    icon: Icons.memory,
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

class _EmbeddedSearch extends StatelessWidget {
  final List<SettingsItem> items;

  const _EmbeddedSearch({required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SettingsSearchSheet(items: items));
  }
}

class _SearchLauncher extends StatefulWidget {
  final List<SettingsItem> items;

  const _SearchLauncher({required this.items});

  @override
  State<_SearchLauncher> createState() => _SearchLauncherState();
}

class _SearchLauncherState extends State<_SearchLauncher> {
  SettingsItem? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () async {
              final selected = await SettingsSearchSheet.show(
                context: context,
                items: widget.items,
              );
              if (!mounted) return;
              setState(() => _selected = selected);
            },
            child: const Text('Open search'),
          ),
          if (_selected != null) Text('Selected: ${_selected!.id.name}'),
        ],
      ),
    );
  }
}
