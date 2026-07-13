import 'dart:io';

import 'package:bb_mobile/core/wallet/data/datasources/lwk_facade.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.documentsPath);
  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  late Directory documentsDir;
  late WalletModel wallet;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp(
      'lwk_facade_delete_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsDir.path,
    );
    wallet = const WalletModel.publicLwk(
      id: 'elwpkh([86f62c86/84h/1776h/0h])',
      combinedCtDescriptor: 'ct-descriptor-irrelevant-for-this-test',
      isTestnet: false,
    );
  });

  tearDown(() async {
    if (await documentsDir.exists()) {
      await documentsDir.delete(recursive: true);
    }
  });

  // lwk_wollet's WolletBuilder.with_legacy_fs_store treats the path we pass
  // as a base directory and nests the real cache several levels inside it
  // (<dbPath>/<network>/enc_cache/<descriptor hash>/...) — it is never a
  // plain file at <dbPath> itself.
  Future<Directory> seedCacheDir() async {
    final dbPath = Directory('${documentsDir.path}/${wallet.hexId}');
    final nested = Directory(
      '${dbPath.path}/liquid/enc_cache/some-descriptor-hash',
    );
    await nested.create(recursive: true);
    await File('${nested.path}/store').writeAsString('cached-wollet-data');
    return dbPath;
  }

  test('deletes an existing cache directory instead of reporting notFound', () async {
    final dbPath = await seedCacheDir();
    expect(await dbPath.exists(), isTrue);

    await LwkFacade.delete(wallet);

    expect(await dbPath.exists(), isFalse);
  });

  test('throws WalletError.notFound when no cache exists', () async {
    await expectLater(
      LwkFacade.delete(wallet),
      throwsA(isA<WalletError>()),
    );
  });
}
