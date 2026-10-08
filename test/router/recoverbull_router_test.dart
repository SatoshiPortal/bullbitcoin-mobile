import 'dart:io';

import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

final class _Logger implements LogSink {
  @override
  void fine(String message, {Object? error, StackTrace? trace}) {}

  @override
  void info(String message, {Object? error, StackTrace? trace}) {}

  @override
  void error(String message, {Object? error, StackTrace? trace}) {}

  @override
  void warning(String message, {Object? error, StackTrace? trace}) {}

  @override
  LogSink scoped(String scope) => this;
}

final class _Settings extends Mock implements RecoverBullSettingsPort {}

final class _Wallets extends Mock implements RecoverBullWalletRepository {}

final class _Seeds extends Mock implements RecoverBullSeedPort {}

final class _Defaults extends Mock implements RecoverBullDefaultWalletsPort {}

final class _Tor extends Mock implements Tor {}

final class _EmbeddedTor extends Mock implements EmbeddedTor {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('complete app router has unique route names', () async {
    final tor = _Tor();
    final embedded = _EmbeddedTor();
    final tempDirectory = await Directory.systemTemp.createTemp(
      'recoverbull-router-',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    when(() => tor.embedded).thenReturn(embedded);
    when(() => embedded.watcher).thenReturn(_WatchTorConnection());
    final feature = await RecoverBullFeature.create(
      config: RecoverBullConfig(
        databasePath: '${tempDirectory.path}/recoverbull.sqlite',
      ),
      wallets: _Wallets(),
      seeds: _Seeds(),
      defaultWallets: _Defaults(),
      settings: _Settings(),
      tor: tor,
      log: _Logger(),
    );
    locator.registerSingleton<RecoverBullFeature>(feature);

    final router = AppRouter.router;
    final names = _routeNames(router.configuration.routes);
    expect(names.toSet(), hasLength(names.length));

    await feature.lifecycle.dispose();
    await locator.reset();
  });
}

List<String> _routeNames(List<RouteBase> routes) => [
  for (final route in routes)
    if (route is GoRoute) ...[
      if (route.name != null) route.name!,
      ..._routeNames(route.routes),
    ] else if (route is ShellRoute)
      ..._routeNames(route.routes),
];

final class _WatchTorConnection extends Mock
    implements WatchTorConnectionUsecase {}
