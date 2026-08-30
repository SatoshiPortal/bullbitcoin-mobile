import 'dart:io';

import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'disposes owned resources exactly once in wallet-then-persister order',
    () async {
      final order = <String>[];

      final result = await BdkFacade.runWithDisposal(
        action: () async => 7,
        disposeWallet: () => order.add('wallet'),
        disposePersister: () => order.add('persister'),
      );

      expect(result, 7);
      expect(order, ['wallet', 'persister']);
    },
  );

  test('disposes both resources in order when the callback throws', () async {
    final order = <String>[];

    await expectLater(
      BdkFacade.runWithDisposal<void>(
        action: () => throw StateError('probe'),
        disposeWallet: () => order.add('wallet'),
        disposePersister: () => order.add('persister'),
      ),
      throwsStateError,
    );

    expect(order, ['wallet', 'persister']);
  });

  test('production datasource has no unscoped wallet reconstruction', () {
    final source = File(
      'lib/core/wallet/data/datasources/bdk_wallet_datasource.dart',
    ).readAsStringSync();

    expect(
      RegExp(
        r'BdkFacade\.create(?:Wallet|PublicWallet|PrivateWallet)',
      ).allMatches(source),
      isEmpty,
    );
  });

  test('facade exposes only scoped wallet ownership', () {
    final source = File(
      'lib/core/wallet/data/datasources/bdk_facade.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('static Future<bdk.Wallet> create')));
    expect(source, isNot(contains('static Future<BdkWalletHandle>')));
    expect(source, isNot(contains('static void disposeWallet')));
    expect(source, contains('static Future<T> withWallet<T>'));
  });

  test('raw BDK ownership creation stays in audited scopes', () {
    final rawCreation = RegExp(r'bdk\.(?:Wallet|Persister)\s*(?:\(|\.new)');
    final productionFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final violations = <String>[];
    for (final file in productionFiles) {
      final source = file.readAsStringSync();
      if (rawCreation.hasMatch(source) &&
          !file.path.endsWith('bdk_facade.dart') &&
          !file.path.endsWith('bdk_wallet_datasource.dart')) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty);
  });
}
