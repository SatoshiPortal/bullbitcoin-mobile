import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import 'search_registry.dart';

void main() {
  for (final network in NetworkEnv.values) {
    test('Ark wallet settings obey canonical network policy on $network', () {
      final items = buildSettingsItems(
        localization: AppLocalizationsEn(),
        environment: network,
      );
      final ark = items.where((item) => item.id == SettingsItemId.ark);
      expect(ark.isNotEmpty, network == NetworkEnv.regtest);
      if (ark.isNotEmpty) {
        expect(ark.single.section, SettingsItemSection.wallet);
        expect(ark.single.path, ['Settings', 'Wallet', 'Ark']);
        expect(searchRegistry(items, 'ark').first.id, SettingsItemId.ark);
      }
    });
  }
  testWidgets('Ark search result opens the same explicit module entry', (
    tester,
  ) async {
    final item = buildSettingsItems(
      localization: AppLocalizationsEn(),
      environment: NetworkEnv.regtest,
    ).byId(SettingsItemId.ark);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(body: item.buildTile(context)),
        ),
        GoRoute(
          path: '/ark',
          builder: (_, state) => const Scaffold(body: Text('Ark module entry')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: testBullExtensions),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ark'));
    await tester.pumpAndSettle();
    expect(find.text('Ark module entry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
}
