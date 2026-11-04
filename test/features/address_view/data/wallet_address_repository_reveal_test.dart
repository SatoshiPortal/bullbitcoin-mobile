// A receive address skipped past a system label is peeked, not revealed, and
// routine syncs only query revealed scripts: the returned address must be
// revealed and persisted before the user can be paid on it.
import 'dart:io';

import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/address_view/data/labeled_wallet_address_repository_impl.dart';
import 'package:bb_mobile/features/address_view/public/address_view_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show InMemoryWalletSourceOperationCoordinator;

class _MockWalletCatalogPort extends Mock implements WalletCatalogPort {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

// The canonical BIP39 test mnemonic. Public knowledge, no funds.
const _testMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

const _walletId = 'wpkh([73c5da0a/84h/1h/0h])';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PublicBdkWalletModel walletModel;
  late LabeledWalletAddressRepository repository;
  late BdkWalletDatasource datasource;
  late Set<String> systemLabelled;
  late List<String> labelLookups;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wallet_address_reveal_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDir.path;
          }
          return null;
        });

    final secretKey = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.test,
      mnemonic: bdk.Mnemonic.fromString(mnemonic: _testMnemonic),
      password: null,
    );
    String descriptor(bdk.KeychainKind keychain) => bdk.Descriptor.newBip84(
      secretKey: secretKey,
      keychainKind: keychain,
      networkKind: bdk.NetworkKind.test,
    ).toString();
    final external = descriptor(bdk.KeychainKind.external_);
    final internal = descriptor(bdk.KeychainKind.internal);
    walletModel =
        WalletModel.publicBdk(
              id: _walletId,
              externalDescriptor: external,
              internalDescriptor: internal,
              isTestnet: true,
            )
            as PublicBdkWalletModel;

    // Two revealed, unused receive addresses: index 1 is the current one.
    final nativeAddresses = BdkWalletDatasource();
    await nativeAddresses.getNewAddress(wallet: walletModel);
    await nativeAddresses.getNewAddress(wallet: walletModel);

    final metadata = _MockWalletCatalogPort();
    when(() => metadata.fetch(_walletId)).thenAnswer(
      (_) async => WalletMetadata(
        id: _walletId,
        masterFingerprint: '73c5da0a',
        xpubFingerprint: 'deadbeef',
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        xpub: 'tpub-test',
        externalPublicDescriptor: external,
        internalPublicDescriptor: internal,
        signer: SignerEntity.local,
        isDefault: false,
      ),
    );
    systemLabelled = {};
    labelLookups = [];
    final labels = _MockLabelsFacade();
    when(() => labels.fetchByReference(any())).thenAnswer((invocation) async {
      final address = invocation.positionalArguments.single as String;
      labelLookups.add(address);
      return [
        if (systemLabelled.contains(address))
          Label.addr(id: 1, address: address, label: LabelSystem.swaps.label)
        else
          Label.addr(id: 2, address: address, label: 'receive label'),
      ];
    });

    datasource = BdkWalletDatasource();
    repository = LabeledWalletAddressRepositoryImpl(
      labels: labels,
      wallet: WalletAddressRepository(
        walletMetadataDatasource: metadata,
        bdkWalletDatasource: datasource,
        lwkWalletDatasource: _MockLwkWalletDatasource(),
        coordinator: InMemoryWalletSourceOperationCoordinator(),
      ),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<int> persistedLastRevealedIndex() =>
      BdkWalletDatasource().getLastRevealedAddressIndex(wallet: walletModel);

  test('the current address skipped past a system label is revealed', () async {
    systemLabelled.add(
      await datasource.getAddressByIndex(1, wallet: walletModel),
    );

    final address = await repository.getLastRevealedReceiveAddress(
      walletId: _walletId,
    );

    expect(address.index, 2);
    expect(labelLookups, [systemLabelled.single, address.address]);
    expect(address.labels.single.label, 'receive label');
    expect(await persistedLastRevealedIndex(), greaterThanOrEqualTo(2));
  });

  test('a new address skipped past a system label is revealed', () async {
    systemLabelled.add(
      await datasource.getAddressByIndex(2, wallet: walletModel),
    );

    final address = await repository.generateNewReceiveAddress(
      walletId: _walletId,
    );

    expect(address.index, 3);
    expect(labelLookups, [systemLabelled.single, address.address]);
    expect(address.labels.single.label, 'receive label');
    expect(await persistedLastRevealedIndex(), greaterThanOrEqualTo(3));
  });
}
