import 'dart:io';

import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('bdk_facade_load_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDirectory.path;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('a missing public wallet is created and can be loaded again', () async {
    final model = _publicWallet('bdk-facade-new-public', bip84: true);
    final dbFile = File('${tempDirectory.path}/${model.hexId}_bdk_dart');
    expect(await dbFile.exists(), isFalse);

    await BdkFacade.withWallet(model, (created) async {
      expect(await dbFile.exists(), isTrue);
    });

    await BdkFacade.withWallet(model, (loaded) {
      expect(loaded.network(), bdk.Network.testnet);
    });
  });

  test('deletion invalidates an already opened wallet persister', () async {
    final model = _publicWallet('bdk-facade-deleted-public', bip84: true);
    final dbFile = File('${tempDirectory.path}/${model.hexId}_bdk_dart');
    await BdkFacade.withWallet(model, (wallet) async {
      await BdkFacade.delete(model);
      await expectLater(
        BdkFacade.saveWallet(wallet, model.hexId),
        throwsStateError,
      );
    });
    expect(await dbFile.exists(), isFalse);
  });

  test(
    'a retained private signer is rejected after its scope closes',
    () async {
      final wallet =
          WalletModel.privateBdk(
                id: 'bdk-facade-private-signer',
                scriptType: ScriptType.bip84,
                mnemonic: _mnemonic,
                passphrase: null,
                isTestnet: true,
              )
              as PrivateBdkWalletModel;
      String Function(String)? retained;

      await BdkWalletDatasource().withPsbtSigner(
        wallet: wallet,
        operation: (signer) async {
          retained = signer;
        },
      );

      expect(() => retained!('not-a-psbt'), throwsStateError);
    },
  );

  test(
    'a malformed internal descriptor does not leave a database handle',
    () async {
      final valid = _publicWallet('bdk-facade-partial-public', bip84: true);
      final malformed =
          WalletModel.publicBdk(
                id: valid.id,
                externalDescriptor: valid.externalDescriptor,
                internalDescriptor: 'not-a-descriptor',
                isTestnet: true,
              )
              as PublicBdkWalletModel;
      final dbFile = File('${tempDirectory.path}/${malformed.hexId}_bdk_dart');

      for (var attempt = 0; attempt < 20; attempt++) {
        await expectLater(
          BdkFacade.withWallet(malformed, (_) async {}),
          throwsA(anything),
        );
        expect(await dbFile.exists(), isFalse);
      }
    },
  );

  test('public wallet load failure preserves the existing BDK file', () async {
    final first = _publicWallet('bdk-facade-public', bip84: true);
    final incompatible = _publicWallet('bdk-facade-public', bip84: false);

    final dbFile = File('${tempDirectory.path}/${first.hexId}_bdk_dart');
    await dbFile.writeAsBytes(const [0x6e, 0x6f, 0x74, 0x2d, 0x73, 0x71, 0x6c]);
    final before = await dbFile.readAsBytes();

    await expectLater(
      BdkFacade.withWallet(incompatible, (_) async {}),
      throwsA(anything),
    );
    expect(await dbFile.exists(), isTrue);
    expect(await dbFile.readAsBytes(), before);
  });

  test('private wallet load failure preserves the existing BDK file', () async {
    final first = WalletModel.privateBdk(
      id: 'bdk-facade-private',
      scriptType: ScriptType.bip84,
      mnemonic: _mnemonic,
      isTestnet: true,
    );
    final incompatible = WalletModel.privateBdk(
      id: first.id,
      scriptType: ScriptType.bip49,
      mnemonic: _mnemonic,
      isTestnet: true,
    );

    final dbFile = File('${tempDirectory.path}/${first.hexId}_bdk_dart');
    await dbFile.writeAsBytes(const [0x6e, 0x6f, 0x74, 0x2d, 0x73, 0x71, 0x6c]);
    final before = await dbFile.readAsBytes();

    await expectLater(
      BdkFacade.withWallet(incompatible, (_) async {}),
      throwsA(anything),
    );
    expect(await dbFile.exists(), isTrue);
    expect(await dbFile.readAsBytes(), before);
  });
}

PublicBdkWalletModel _publicWallet(String id, {required bool bip84}) {
  final secretKey = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.test,
    mnemonic: bdk.Mnemonic.fromString(mnemonic: _mnemonic),
    password: null,
  );
  final external = bip84
      ? bdk.Descriptor.newBip84(
          secretKey: secretKey,
          keychainKind: bdk.KeychainKind.external_,
          networkKind: bdk.NetworkKind.test,
        )
      : bdk.Descriptor.newBip49(
          secretKey: secretKey,
          keychainKind: bdk.KeychainKind.external_,
          networkKind: bdk.NetworkKind.test,
        );
  final internal = bip84
      ? bdk.Descriptor.newBip84(
          secretKey: secretKey,
          keychainKind: bdk.KeychainKind.internal,
          networkKind: bdk.NetworkKind.test,
        )
      : bdk.Descriptor.newBip49(
          secretKey: secretKey,
          keychainKind: bdk.KeychainKind.internal,
          networkKind: bdk.NetworkKind.test,
        );
  return WalletModel.publicBdk(
        id: id,
        externalDescriptor: external.toString(),
        internalDescriptor: internal.toString(),
        isTestnet: true,
      )
      as PublicBdkWalletModel;
}
