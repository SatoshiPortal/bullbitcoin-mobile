import 'dart:ui';

import 'package:bull_logs/bull_logs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  test('publishes the route through the feature facade', () {
    const facade = LogsFeature();

    expect(facade.route.name, 'logs');
    expect(facade.route.path, 'logs');
  });

  test('registers a resolvable runtime facade', () async {
    final locator = GetIt.asNewInstance();
    addTearDown(locator.reset);

    const LogsFeature().setup(locator);

    expect(locator<LogsFacade>(), isA<LogsFacade>());
  });

  test('loads package translations and falls back to the template', () async {
    final french = await LogsLocalizations.delegate.load(const Locale('fr'));
    final unsupported = await LogsLocalizations.delegate.load(
      const Locale('en', 'GB'),
    );

    expect(french.logsShareOptionShare, isNotEmpty);
    expect(unsupported.logsShareOptionShare, 'Share');
  });
}
