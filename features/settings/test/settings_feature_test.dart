import 'dart:async';

import 'package:bull_ui/bull_ui.dart' show BullSettingsEntryItem;
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:network/network.dart';
import 'package:network/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/settings.dart';

const _searchBar = Key('settings-search-bar');
const _searchField = Key('settings-search-field');

void main() {
  test('mounts the preference routes without opening foreground services', () {
    final feature = SettingsFeature.mount(
      status: networkStatusForTest(
        () async => const Err(NoDefaultWalletFailure()),
      ),
      settings: () => throw StateError('services must be resolved lazily'),
      childRoutes: const [],
    );
    final children = feature.route.routes.whereType<GoRoute>();
    expect(
      children.map((route) => route.name),
      containsAll([
        'walletSettings',
        'payjoinSettings',
        'payjoinAdvancedSettings',
      ]),
    );
    final app = children.singleWhere((route) => route.name == 'appSettings');
    expect(app.path, 'app-settings');
    expect(app.routes.whereType<GoRoute>().single.path, 'permissions');
  });

  testWidgets('keeps the home, search and child route contracts', (
    tester,
  ) async {
    await _mount(tester);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Version 1.2.3'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Services')).dy,
      lessThan(tester.getTopLeft(find.text('Logs')).dy),
    );
    expect(find.text('Tor'), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    final search = find.byKey(_searchBar);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      final node = tester.getSemantics(search);
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isTextField, isFalse);
      expect(node.label, 'Search settings');
    } finally {
      semantics.dispose();
    }
    expect(tester.getSize(search).height, greaterThanOrEqualTo(48));

    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(find.text('Start typing'), findsOneWidget);
    await tester.enterText(find.byKey(_searchField), 'anonymous');
    await tester.pump();
    expect(find.text('Settings → Network → Tor'), findsOneWidget);
    await tester.tap(find.text('Tor'));
    await tester.pumpAndSettle();
    expect(find.text('Tor destination'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Settings → Network → Tor'), findsOneWidget);
    expect(find.text('anonymous'), findsOneWidget);
  });

  testWidgets('keeps the direct /settings/search URL', (tester) async {
    await _mount(tester, initialLocation: '/settings/search');
    expect(find.byKey(_searchField), findsOneWidget);
    expect(find.text('Start typing'), findsOneWidget);
  });

  testWidgets('refreshes the menu without resetting the current query', (
    tester,
  ) async {
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    await _mount(
      tester,
      initialLocation: '/settings/search',
      menuScope: (child) => ValueListenableBuilder(
        valueListenable: ready,
        builder: (_, value, _) => _MenuAvailability(ready: value, child: child),
      ),
    );
    await tester.enterText(find.byKey(_searchField), 'account');
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);

    ready.value = true;
    await tester.pump();
    expect(find.text('Account'), findsOneWidget);

    ready.value = false;
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);
    expect(find.text('account'), findsOneWidget);
  });

  testWidgets('owns one status check per home mount, not per child route', (
    tester,
  ) async {
    final checks = <Completer<Result<AllServicesStatus, NetworkFailure>>>[];
    await _mount(
      tester,
      status: networkStatusForTest(() {
        final pending = Completer<Result<AllServicesStatus, NetworkFailure>>();
        checks.add(pending);
        return pending.future;
      }),
    );
    expect(checks, isEmpty);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(checks, hasLength(1));
    expect(_serviceColor(tester), testBullTheme.textMuted);
    await tester.tap(find.byKey(_searchBar));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(checks, hasLength(1));

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(checks, hasLength(2));

    // A late completion from the previous home cannot change the new one.
    checks.first.complete(const Err(NoDefaultWalletFailure()));
    await tester.idle();
    await tester.pump();
    expect(_serviceColor(tester), testBullTheme.textMuted);
    checks.last.complete(const Err(NoDefaultWalletFailure()));
    await tester.idle();
    await tester.pump();
    expect(_serviceColor(tester), testBullTheme.error);
  });

  testWidgets('shows a healthy color when the required services are up', (
    tester,
  ) async {
    const online = ServiceStatusInfo(status: ServiceStatus.online);
    await _mount(
      tester,
      initialLocation: '/settings',
      status: networkStatusForTest(
        () async => const Ok(
          AllServicesStatus(
            internetConnection: online,
            bitcoinElectrum: online,
            liquidElectrum: online,
            payjoin: ServiceStatusInfo(status: ServiceStatus.disabled),
            pricer: online,
            mempool: online,
          ),
        ),
      ),
    );
    expect(_serviceColor(tester), testBullTheme.success);
  });
}

Color? _serviceColor(WidgetTester tester) => tester
    .widget<BullSettingsEntryItem>(
      find.ancestor(
        of: find.text('Services'),
        matching: find.byType(BullSettingsEntryItem),
      ),
    )
    .iconColor;

Future<void> _mount(
  WidgetTester tester, {
  String initialLocation = '/',
  NetworkStatus? status,
  Widget Function(Widget child)? menuScope,
}) async {
  final module = SettingsFeature.mount(
    menuOf: (context) => (
      appVersion: '1.2.3',
      entries: [
        SettingsEntry(
          id: 'services',
          title: 'Services',
          breadcrumbs: const ['Settings', 'Services'],
          icon: Icons.monitor_heart,
          open: (_) {},
          showOnHome: true,
          indicatesServiceHealth: true,
        ),
        SettingsEntry(
          id: 'tor',
          title: 'Tor',
          breadcrumbs: const ['Settings', 'Network', 'Tor'],
          icon: Icons.language,
          keywords: const ['anonymous'],
          open: (context) => context.pushNamed<void>('tor'),
        ),
        SettingsEntry(
          id: 'logs',
          title: 'Logs',
          breadcrumbs: const ['Settings', 'Logs'],
          icon: Icons.article,
          open: (_) {},
          showOnHome: true,
        ),
        if (context
                .dependOnInheritedWidgetOfExactType<_MenuAvailability>()
                ?.ready ??
            false)
          SettingsEntry(
            id: 'account',
            title: 'Account',
            breadcrumbs: const ['Settings', 'Account'],
            icon: Icons.person,
            open: (_) {},
          ),
      ],
    ),
    labelsOf: (_) => (
      title: 'Settings',
      searchHint: 'Search settings',
      searchStartTyping: 'Start typing',
      searchNoResults: 'No results',
      appVersionLabel: 'Version ',
    ),
    status:
        status ??
        networkStatusForTest(() async => const Err(NoDefaultWalletFailure())),
    menuScope: menuScope,
    childRoutes: [
      GoRoute(
        path: 'tor',
        name: 'tor',
        builder: (_, _) =>
            Scaffold(appBar: AppBar(title: const Text('Tor destination'))),
      ),
    ],
  );
  expect(module.route.path, '/settings');
  expect(module.route.name, 'settings');
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => SettingsNavigation.open(context),
            child: const Text('Open settings'),
          ),
        ),
      ),
      module.route,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: testBullExtensions),
    ),
  );
  await tester.pumpAndSettle();
}

class _MenuAvailability extends InheritedWidget {
  final bool ready;

  const _MenuAvailability({required this.ready, required super.child});

  @override
  bool updateShouldNotify(_MenuAvailability oldWidget) =>
      ready != oldWidget.ready;
}
