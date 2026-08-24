import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Wallets extends Mock implements WalletRepository {}

class _Seeds extends Mock implements SeedRepository {}

void main() {
  final bytes = Uint8List.fromList(List.generate(16, (index) => index));
  final fingerprint = hex.encode(bip32.Bip32Keys.fromSeed(bytes).fingerprint);
  late _Wallets wallets;
  late _Seeds seeds;
  late GetDefaultSeedUsecase usecase;

  setUp(() {
    wallets = _Wallets();
    seeds = _Seeds();
    usecase = GetDefaultSeedUsecase(
      walletRepository: wallets,
      seedRepository: seeds,
    );
  });

  test('returns the verified seed without loading wallet balances', () async {
    final seed = Seed.bytes(
      bytes: bytes,
      masterFingerprint: fingerprint,
    );
    when(
      () => wallets.getDefaultBitcoinWalletFingerprints(
        environment: Environment.mainnet,
      ),
    ).thenAnswer((_) async => [fingerprint]);
    when(() => seeds.get(fingerprint)).thenAnswer((_) async => seed);

    final result = await usecase.execute(environment: Environment.mainnet);

    expect(result, isA<Ok<Seed, SeedFailure>>());
    verifyNever(
      () => wallets.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
      ),
    );
  });

  test('rejects an ambiguous default-wallet trust root', () async {
    when(
      () => wallets.getDefaultBitcoinWalletFingerprints(
        environment: Environment.mainnet,
      ),
    ).thenAnswer((_) async => [fingerprint, fingerprint]);

    final result = await usecase.execute(environment: Environment.mainnet);

    expect(result, isA<Err<Seed, SeedFailure>>());
    expect((result as Err).failure, isA<DefaultSeedAmbiguousFailure>());
    verifyNever(() => seeds.get(any()));
  });

  test('rejects seed bytes that do not match the wallet fingerprint', () async {
    final otherBytes = Uint8List.fromList(List.generate(16, (index) => index + 1));
    final seed = Seed.bytes(
      bytes: otherBytes,
      masterFingerprint: fingerprint,
    );
    when(
      () => wallets.getDefaultBitcoinWalletFingerprints(
        environment: Environment.mainnet,
      ),
    ).thenAnswer((_) async => [fingerprint]);
    when(() => seeds.get(fingerprint)).thenAnswer((_) async => seed);

    final result = await usecase.execute(environment: Environment.mainnet);

    expect(result, isA<Err<Seed, SeedFailure>>());
    expect(
      (result as Err).failure,
      isA<DefaultSeedFingerprintMismatchFailure>(),
    );
  });

  test('does not catch programmer errors', () async {
    when(
      () => wallets.getDefaultBitcoinWalletFingerprints(
        environment: Environment.mainnet,
      ),
    ).thenThrow(StateError('programmer error'));

    await expectLater(
      usecase.execute(environment: Environment.mainnet),
      throwsStateError,
    );
  });
}
