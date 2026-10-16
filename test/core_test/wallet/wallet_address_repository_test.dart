import 'dart:io';

import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Labels extends Mock implements LabelsFacade {}

class _Liquid extends Mock implements LwkWalletDatasource {}

// Public BIP39 test vector; no network or funded fixtures are used.
const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';
const _id = 'wpkh([00000001/84h/1h/0h])';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PublicBdkWalletModel wallet;
  late BdkWalletDatasource datasource;
  late WalletAddressRepository repository;
  late Map<String, String> labels;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('receive_skip_labels_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => call.method == 'getApplicationDocumentsDirectory'
              ? directory.path
              : null,
        );
    final key = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.test,
      mnemonic: bdk.Mnemonic.fromString(mnemonic: _mnemonic),
      password: null,
    );
    final external = bdk.Descriptor.newBip84(
      secretKey: key,
      keychainKind: bdk.KeychainKind.external_,
      networkKind: bdk.NetworkKind.test,
    );
    final internal = bdk.Descriptor.newBip84(
      secretKey: key,
      keychainKind: bdk.KeychainKind.internal,
      networkKind: bdk.NetworkKind.test,
    );
    final metadata = WalletMetadataModel(
      id: _id,
      masterFingerprint: '00000001',
      xpubFingerprint: '00000001',
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      xpub: 'not needed by address derivation',
      externalPublicDescriptor: external.toString(),
      internalPublicDescriptor: internal.toString(),
      signer: Signer.local,
      isDefault: true,
    );
    wallet = WalletModel.fromMetadata(metadata) as PublicBdkWalletModel;
    datasource = BdkWalletDatasource();
    final metadataStore = _Metadata();
    when(() => metadataStore.fetch(_id)).thenAnswer((_) async => metadata);
    labels = {};
    final labelStore = _Labels();
    when(() => labelStore.fetchByReference(any())).thenAnswer((call) async {
      final address = call.positionalArguments.first as String;
      final label = labels[address];
      return label == null
          ? []
          : [Label.addr(id: 1, address: address, label: label)];
    });
    repository = WalletAddressRepository(
      walletMetadataDatasource: metadataStore,
      bdkWalletDatasource: datasource,
      lwkWalletDatasource: _Liquid(),
      labelsFacade: labelStore,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await directory.delete(recursive: true);
  });

  for (final generateNew in [false, true]) {
    for (final skipped in [1, 2]) {
      test('selected address is not reissued after $skipped system labels '
          '(generateNew=$generateNew)', () async {
        for (var index = 0; index < skipped; index++) {
          final address = await datasource.getAddressByIndex(
            index,
            wallet: wallet,
          );
          labels[address] = LabelSystem.payjoin.label;
        }
        final selected = generateNew
            ? await repository.generateNewReceiveAddress(walletId: _id)
            : await repository.getLastRevealedReceiveAddress(walletId: _id);
        expect(selected.index, skipped);
        final next = await repository.generateNewReceiveAddress(walletId: _id);
        expect(
          next.address,
          isNot(selected.address),
          reason:
              'An explicitly new request must not reuse the skipped-to address',
        );
        expect(next.index, skipped + 1);
      });
    }
  }

  test('listing an address does not reveal it', () async {
    await repository.getAddressAtIndex(
      walletId: _id,
      index: 20,
      isChange: false,
    );
    expect(await datasource.getLastRevealedAddressIndex(wallet: wallet), -1);
  });

  test('user labels are preserved without skipping their address', () async {
    final address = await datasource.getAddressByIndex(0, wallet: wallet);
    labels[address] = 'invoice';
    final selected = await repository.generateNewReceiveAddress(walletId: _id);
    expect(selected.address, address);
    expect(selected.index, 0);
    expect(selected.labels.single.label, 'invoice');
  });
}
