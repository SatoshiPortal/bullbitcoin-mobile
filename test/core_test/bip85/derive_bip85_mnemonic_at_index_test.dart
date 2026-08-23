import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/derive_bip85_mnemonic_at_index_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Wallets extends Mock implements WalletRepository {}

class _Seeds extends Mock implements SeedRepository {}

void main() {
  late SqliteDatabase database;
  late Bip85Repository repository;
  late _Wallets wallets;
  late _Seeds seeds;
  late DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase usecase;
  late BytesSeed seed;
  late Wallet wallet;

  setUp(() {
    final bytes = Uint8List.fromList(List.generate(16, (index) => index));
    final fingerprint = hex.encode(bip32.Bip32Keys.fromSeed(bytes).fingerprint);
    seed =
        Seed.bytes(bytes: bytes, masterFingerprint: fingerprint) as BytesSeed;
    wallet = Wallet(
      origin: 'default',
      network: Network.bitcoinMainnet,
      isDefault: true,
      masterFingerprint: fingerprint,
      xpubFingerprint: fingerprint,
      scriptType: ScriptType.bip84,
      xpub: 'xpub',
      externalPublicDescriptor: 'external',
      internalPublicDescriptor: 'internal',
      signer: SignerEntity.local,
      signerDevice: null,
      balanceSat: BigInt.zero,
    );
    database = SqliteDatabase(NativeDatabase.memory());
    repository = Bip85Repository(datasource: Bip85Datasource(sqlite: database));
    wallets = _Wallets();
    seeds = _Seeds();
    usecase = DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase(
      bip85Repository: repository,
      walletRepository: wallets,
      seedRepository: seeds,
    );
    when(
      () => wallets.getWallets(
        environment: Environment.mainnet,
        onlyDefaults: true,
        onlyBitcoin: true,
      ),
    ).thenAnswer((_) async => [wallet]);
    when(
      () => seeds.get(wallet.masterFingerprint),
    ).thenAnswer((_) async => seed);
    addTearDown(database.close);
  });

  test('fixed derivation is idempotent and rejects another owner', () async {
    final first = await usecase.execute(
      index: 100,
      alias: 'BTCPay',
      environment: Environment.mainnet,
    );
    final second = await usecase.execute(
      index: 100,
      alias: 'BTCPay',
      environment: Environment.mainnet,
    );
    final conflict = await usecase.execute(
      index: 100,
      alias: 'Another Product',
      environment: Environment.mainnet,
    );

    expect(first, isA<Ok<dynamic, Bip85Failure>>());
    expect(second, isA<Ok<dynamic, Bip85Failure>>());
    expect(_value(first).derivation, "39'/0'/12'/100'");
    expect(_value(second).mnemonic.sentence, _value(first).mnemonic.sentence);
    expect(conflict, isA<Err<dynamic, Bip85Failure>>());
    expect((conflict as Err).failure, isA<Bip85DerivationConflictFailure>());
    expect(
      await database.select(database.bip85Derivations).get(),
      hasLength(1),
    );
  });

  test('replaces a reservation left by a different default seed', () async {
    final staleBytes = Uint8List.fromList(List.generate(16, (i) => i + 16));
    final staleXprv = Bip32Derivation.getCanonicalRootXprvFromSeed(staleBytes);
    final stale = await repository.deriveMnemonic(
      xprvBase58: staleXprv,
      length: bip39.MnemonicLength.words12,
      index: 100,
      alias: 'BTCPay',
    );

    final result = await usecase.execute(
      index: 100,
      alias: 'BTCPay',
      environment: Environment.mainnet,
    );
    final stored = await repository.fetch("39'/0'/12'/100'");

    expect(stale, isA<Ok<dynamic, Bip85Failure>>());
    expect(result, isA<Ok<dynamic, Bip85Failure>>());
    expect(_value(stored)?.xprvFingerprint, wallet.masterFingerprint);
    expect(_value(stored)?.alias, 'BTCPay');
  });

  test('rejects an ambiguous default-wallet trust root', () async {
    when(
      () => wallets.getWallets(
        environment: Environment.mainnet,
        onlyDefaults: true,
        onlyBitcoin: true,
      ),
    ).thenAnswer((_) async => [wallet, wallet]);

    final result = await usecase.execute(
      index: 100,
      alias: 'BTCPay',
      environment: Environment.mainnet,
    );

    expect(result, isA<Err<dynamic, Bip85Failure>>());
    expect((result as Err).failure, isA<Bip85DefaultWalletAmbiguousFailure>());
    verifyNever(() => seeds.get(any()));
  });

  test('does not silently reuse a revoked reservation', () async {
    final first = await usecase.execute(
      index: 100,
      alias: 'BTCPay',
      environment: Environment.mainnet,
    );
    final stored = await repository.fetch(_value(first).derivation);
    final revoked = await repository.revoke(_value(stored)!);

    final result = await usecase.execute(
      index: 100,
      alias: 'BTCPay',
      environment: Environment.mainnet,
    );

    expect(revoked, isA<Ok<dynamic, Bip85Failure>>());
    expect(result, isA<Err<dynamic, Bip85Failure>>());
    expect((result as Err).failure, isA<Bip85DerivationConflictFailure>());
  });
}

T _value<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('Unexpected failure: $failure'),
};
