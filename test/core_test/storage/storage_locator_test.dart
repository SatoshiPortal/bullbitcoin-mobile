import 'dart:io';

import 'package:bb_mobile/core/storage/storage_locator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  final calls = <MethodCall>[];
  late Directory documentsDirectory;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp(
      'storage-prewarm-',
    );
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return false;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => documentsDirectory.path,
        );
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    calls.clear();
    await documentsDirectory.delete(recursive: true);
  });

  test('prewarm initializes FSS10 on a fresh install', () async {
    await StorageLocator.prewarmSecureStorage();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'containsKey');
    expect(calls.single.arguments, {
      'key': '__bull_secure_storage_prewarm__',
      'options': containsPair('migrateOnAlgorithmChange', 'false'),
    });
  });

  test('prewarm skips an install with a storage-library flag', () async {
    SharedPreferences.setMockInitialValues({
      'seed_store_type': '{"storageLibrary":"fss9"}',
    });

    await StorageLocator.prewarmSecureStorage();

    expect(calls, isEmpty);
  });

  test('prewarm skips a flagless install with a database', () async {
    await File('${documentsDirectory.path}/bullbitcoin_sqlite.sqlite').create();

    await StorageLocator.prewarmSecureStorage();

    expect(calls, isEmpty);
  });

  test('prewarm skips a pre-v5 install with a Hive box', () async {
    await File('${documentsDirectory.path}/wallet.hive').create();

    await StorageLocator.prewarmSecureStorage();

    expect(calls, isEmpty);
  });

  test('prewarm fails closed when prior-install inspection fails', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) => throw PlatformException(code: 'path_error'),
        );

    await expectLater(StorageLocator.prewarmSecureStorage(), completes);

    expect(calls, isEmpty);
  });

  test('prewarm fails closed when the storage flag is malformed', () async {
    SharedPreferences.setMockInitialValues({'seed_store_type': 'not-json'});

    await expectLater(StorageLocator.prewarmSecureStorage(), completes);

    expect(calls, isEmpty);
  });

  test('prewarm leaves initialization failures to the startup probe', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          throw PlatformException(code: 'storage_error');
        });

    await expectLater(StorageLocator.prewarmSecureStorage(), completes);

    expect(calls, hasLength(1));
  });

  group('fresh-install probe', () {
    const legacyChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage_legacy',
    );
    final legacyCalls = <MethodCall>[];

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(legacyChannel, (call) async {
            legacyCalls.add(call);
            return <String, String>{};
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(legacyChannel, null);
      legacyCalls.clear();
    });

    Future<String?> storedLibraryFlag() async =>
        (await SharedPreferences.getInstance()).getString('seed_store_type');

    test('commits fss10 once a write decrypts back', () async {
      final store = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            final args = call.arguments as Map;
            final key = args['key'] as String?;
            switch (call.method) {
              case 'readAll':
                return Map<String, String>.of(store);
              case 'write':
                store[key!] = args['value'] as String;
              case 'read':
                return store[key];
              case 'delete':
                store.remove(key);
            }
            return null;
          });

      await StorageLocator.registerDatasources(GetIt.asNewInstance());

      expect(calls.map((c) => c.method), [
        'readAll',
        'write',
        'read',
        'delete',
      ]);
      expect(store, isEmpty);
      expect(legacyCalls, isEmpty);
      expect(await storedLibraryFlag(), contains('fss10'));
    });

    test('routes to fss9 when an empty store cannot encrypt', () async {
      // The native plugin cached after a failed cipher init: readAll on the
      // empty store succeeds, the first encryption throws.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'readAll') return <String, String>{};
            throw PlatformException(code: 'Exception encountered');
          });

      await StorageLocator.registerDatasources(GetIt.asNewInstance());

      expect(legacyCalls.map((c) => c.method), ['readAll']);
      expect(await storedLibraryFlag(), contains('fss9'));
    });
  });
}
