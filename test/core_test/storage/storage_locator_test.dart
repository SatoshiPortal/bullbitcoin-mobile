import 'dart:io';

import 'package:bb_mobile/core/storage/storage_locator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
