import 'dart:typed_data';

import 'package:bb_mobile/core/deterministic_wallets/deterministic_wallets.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bdk extends Mock implements BdkWalletDatasource {}

class _Lwk extends Mock implements LwkWalletDatasource {}

class _Servers extends Mock implements ElectrumServersPort {}

void main() {
  const spec = DeterministicWalletSpec(
    id: 'bitcoin',
    network: Network.bitcoinMainnet,
    scriptType: ScriptType.bip84,
    label: 'Product wallet',
    isDefault: false,
    sync: false,
  );
  final mnemonic = bip39.Mnemonic.fromWords(
    words: List.generate(11, (_) => 'zoo') + ['wrong'],
  );
  final bytes = Uint8List.fromList(mnemonic.seed);
  final seed = MnemonicSeed(
    mnemonicWords: mnemonic.words,
    bytes: bytes,
    masterFingerprint: hex.encode(bip32.Bip32Keys.fromSeed(bytes).fingerprint),
  );
  late SqliteDatabase database;
  late WalletMetadataDatasource metadata;
  late WalletRepository wallets;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    metadata = WalletMetadataDatasource(sqlite: database);
    final bdk = _Bdk();
    final lwk = _Lwk();
    when(
      () => bdk.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => lwk.walletSyncFinishedStream,
    ).thenAnswer((_) => const Stream.empty());
    wallets = WalletRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: _Servers(),
    );
    addTearDown(database.close);
  });

  test('reuses matching metadata without loading a wallet balance', () async {
    final expected = await WalletMetadataService.deriveFromSeed(
      seed: seed,
      network: spec.network,
      scriptType: spec.scriptType,
      label: spec.label,
      isDefault: spec.isDefault,
    );
    await metadata.store(expected);

    final result = await wallets.findMatchingDeterministicWallet(
      seed: seed,
      spec: spec,
    );

    expect(result?.walletId, expected.id);
    expect(result?.externalPublicDescriptor, expected.externalPublicDescriptor);
    expect(result?.created, isFalse);
  });

  test('rejects existing metadata with different descriptors', () async {
    final expected = await WalletMetadataService.deriveFromSeed(
      seed: seed,
      network: spec.network,
      scriptType: spec.scriptType,
      label: spec.label,
      isDefault: spec.isDefault,
    );
    await metadata.store(
      expected.copyWith(externalPublicDescriptor: 'different descriptor'),
    );

    await expectLater(
      wallets.findMatchingDeterministicWallet(seed: seed, spec: spec),
      throwsA(isA<DeterministicWalletMismatchException>()),
    );
  });
}
