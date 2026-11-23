import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `registerFactory<T>` / `registerLazySingleton<T>` in a file, by type.
Iterable<String> _registeredTypes(String source) sync* {
  final pattern = RegExp(
    r'register(?:Factory|LazySingleton|Singleton)(?:Async)?<([A-Za-z0-9_]+)>',
  );
  for (final match in pattern.allMatches(source)) {
    yield match.group(1)!;
  }
}

void main() {
  final locatorFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('_locator.dart'))
      .toList();

  test('the locator files were found at all', () {
    // Guards the two tests below from silently passing on an empty list.
    expect(locatorFiles, isNotEmpty);
  });

  test('core locators do not register feature use-cases', () {
    // Rule #7: lib/core is infrastructure and must not depend on a feature.
    // lib/core/exchange used to register five of them, which is how the
    // duplicates below came to exist — the feature registered its own copy too.
    final violations = <String>[];
    for (final file in locatorFiles.where(
      (file) => file.path.startsWith('lib/core/'),
    )) {
      violations.addAll(
        file
            .readAsLinesSync()
            .where(
              (line) =>
                  line.startsWith('import ') &&
                  line.contains('/features/') &&
                  !line.contains('_facade.dart'),
            )
            .map((line) => '${file.path}: ${line.trim()}'),
      );
    }

    expect(violations, isEmpty);
  });

  test('each exchange-order use case has exactly one composition owner', () {
    // `AppLocator.setup` calls `enableRegisteringMultipleInstancesOfOneType`,
    // so get_it accepts a duplicate registration instead of throwing, then
    // resolves the *first* one — leaving the second as dead code that reads
    // like the live wiring. These five were registered twice for about a year
    // with nothing to catch it.
    //
    // Scoped to these types on purpose: duplicate registrations exist
    // elsewhere in the app (swap re-registers much of send), and that is a
    // separate cleanup, not something to smuggle into this test.
    const purchaseRoutes =
        'features/bull_exchange/lib/src/exchange_purchase_routes.dart';
    const owners = {
      'PlacePayOrderUsecase':
          'features/bull_exchange/lib/src/pay/mount_pay.dart',
      'RefreshSellOrderUsecase':
          'features/bull_exchange/lib/src/sell/mount_sell.dart',
      'ConfirmBuyOrderUsecase': purchaseRoutes,
      'RefreshBuyOrderUsecase': purchaseRoutes,
      'AccelerateBuyOrderUsecase': purchaseRoutes,
    };

    // One entry per registration, not per file: a type registered twice inside
    // a single locator is just as dead as one registered across two, and a Set
    // of paths would collapse it to a single owner and pass.
    final wiring = <String, List<String>>{};
    for (final file in locatorFiles) {
      for (final type in _registeredTypes(file.readAsStringSync())) {
        if (owners.containsKey(type)) {
          wiring
              .putIfAbsent(type, () => [])
              .add(file.path.replaceAll(Platform.pathSeparator, '/'));
        }
      }
    }

    // The exchange mounts construct their use cases in the route-owned Bloc.
    for (final path in owners.values.toSet()) {
      final source = File(path).readAsStringSync();
      for (final type in owners.keys) {
        final calls = RegExp('\\b$type\\s*\\(').allMatches(source);
        wiring.putIfAbsent(type, () => []).addAll(calls.map((_) => path));
      }
    }
    for (final entry in owners.entries) {
      expect(wiring[entry.key], [
        entry.value,
      ], reason: '${entry.key} should be wired exactly once by its owner');
    }
  });
}
