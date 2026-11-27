import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings/src/domain/watch_settings_service_health_usecase.dart';
import 'package:settings/src/settings_menu.dart';
import 'package:settings/src/ui/all_settings_screen.dart';

void main() {
  testWidgets('a service-health update repaints only the health entry', (
    tester,
  ) async {
    final health = StreamController<SettingsServiceHealth>();
    addTearDown(health.close);
    var menuBuilds = 0;

    await tester.pumpWidget(
      wrapWithTheme(
        AllSettingsScreen(
          watchServiceHealth: () => health.stream,
          menuOf: (_) {
            menuBuilds++;
            return (
              appVersion: '1.2.3',
              entries: [
                const SettingsEntry(
                  id: 'services',
                  title: 'Services',
                  breadcrumbs: ['Settings', 'Services'],
                  icon: Icons.monitor_heart,
                  open: _noop,
                  showOnHome: true,
                  indicatesServiceHealth: true,
                ),
                const SettingsEntry(
                  id: 'logs',
                  title: 'Logs',
                  breadcrumbs: ['Settings', 'Logs'],
                  icon: Icons.article,
                  open: _noop,
                  showOnHome: true,
                ),
              ],
            );
          },
          labelsOf: (_) => (
            title: 'Settings',
            searchHint: 'Search settings',
            searchStartTyping: 'Start typing',
            searchNoResults: 'No results',
            appVersionLabel: 'Version ',
          ),
          openSearch: (_) {},
        ),
      ),
    );

    // A stream event is delivered in a microtask: pump the frame rendering it.
    Future<void> emit(SettingsServiceHealth state) async {
      health.add(state);
      await tester.pump();
      await tester.pump();
    }

    expect(menuBuilds, 1);
    expect(_serviceColor(tester), testBullTheme.textMuted);

    await emit(SettingsServiceHealth.healthy);

    // The status dot follows the stream…
    expect(_serviceColor(tester), testBullTheme.success);
    // …without rebuilding the menu or the rest of the page.
    expect(menuBuilds, 1);

    await emit(SettingsServiceHealth.unhealthy);
    expect(_serviceColor(tester), testBullTheme.error);
    expect(menuBuilds, 1);
  });

  testWidgets('an explicit home icon wins over the service-health glyph', (
    tester,
  ) async {
    // Broadcast: the screen must not subscribe at all, so no listener exists to
    // drain a single-subscription controller and close it.
    final health = StreamController<SettingsServiceHealth>.broadcast();
    addTearDown(health.close);
    var menuBuilds = 0;

    await tester.pumpWidget(
      wrapWithTheme(
        AllSettingsScreen(
          watchServiceHealth: () => health.stream,
          menuOf: (_) {
            menuBuilds++;
            return (
              appVersion: '1.2.3',
              entries: [
                const SettingsEntry(
                  id: 'services',
                  title: 'Services',
                  breadcrumbs: ['Settings', 'Services'],
                  icon: Icons.monitor_heart,
                  open: _noop,
                  showOnHome: true,
                  indicatesServiceHealth: true,
                  homeIcon: Icon(Icons.code, key: Key('custom-home-icon')),
                ),
              ],
            );
          },
          labelsOf: (_) => (
            title: 'Settings',
            searchHint: 'Search settings',
            searchStartTyping: 'Start typing',
            searchNoResults: 'No results',
            appVersionLabel: 'Version ',
          ),
          openSearch: (_) {},
        ),
      ),
    );

    Future<void> emit(SettingsServiceHealth state) async {
      health.add(state);
      await tester.pump();
      await tester.pump();
    }

    // The entry keeps the icon its owner gave it, and the health subscription
    // never takes its place.
    expect(find.byKey(const Key('custom-home-icon')), findsOneWidget);
    expect(find.byIcon(Icons.monitor_heart), findsNothing);
    expect(health.hasListener, isFalse);
    expect(menuBuilds, 1);

    await emit(SettingsServiceHealth.healthy);
    await emit(SettingsServiceHealth.unhealthy);

    expect(find.byKey(const Key('custom-home-icon')), findsOneWidget);
    expect(find.byIcon(Icons.monitor_heart), findsNothing);
    expect(menuBuilds, 1);
  });
}

void _noop(BuildContext _) {}

/// The health entry renders its icon through `leading`, so the observable
/// colour is the glyph's own, not [BullSettingsEntryItem.iconColor].
Color? _serviceColor(WidgetTester tester) =>
    tester.widget<Icon>(find.byIcon(Icons.monitor_heart)).color;
