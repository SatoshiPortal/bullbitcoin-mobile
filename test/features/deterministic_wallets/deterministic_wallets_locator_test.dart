import 'dart:io';

import 'package:bb_mobile/core/bip85/domain/derive_bip85_mnemonic_at_index_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/deterministic_wallets/deterministic_wallets_locator.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockFixedIndexBip85Usecase extends Mock
    implements DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase {}

void main() {
  late GetIt locator;

  setUp(() {
    locator = GetIt.asNewInstance();
    locator.registerSingleton<WalletRepository>(_MockWalletRepository());
    locator.registerSingleton<SeedRepository>(_MockSeedRepository());
    locator
        .registerSingleton<DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase>(
          _MockFixedIndexBip85Usecase(),
        );
  });

  tearDown(() => locator.reset());

  test('resolves the concrete public facade with registered prerequisites', () {
    DeterministicWalletsLocator.setup(locator);

    expect(locator<DeterministicWalletsFacade>(), isNotNull);
  });

  test('rejects accidental duplicate feature registration', () {
    DeterministicWalletsLocator.setup(locator);

    expect(
      () => DeterministicWalletsLocator.setup(locator),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('composition root registers registry before every consumer', () {
    final source = File('lib/locator.dart').readAsStringSync();
    final registry = source.indexOf('Bip85RegistryLocator.setup(locator)');
    final deterministic = source.indexOf(
      'DeterministicWalletsLocator.setup(locator)',
    );
    final entropy = source.indexOf('Bip85EntropyLocator.setup(locator)');

    expect(registry, greaterThanOrEqualTo(0));
    expect(deterministic, greaterThan(registry));
    expect(entropy, greaterThan(deterministic));
  });
}
