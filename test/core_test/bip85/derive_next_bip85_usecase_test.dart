import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBip85Repository extends Mock implements Bip85Repository {}

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

void main() {
  late _MockBip85Repository bip85Repository;
  late _MockGetDefaultSeedUsecase getDefaultSeed;
  late _MockGetSettingsUsecase getSettings;

  setUp(() {
    bip85Repository = _MockBip85Repository();
    getDefaultSeed = _MockGetDefaultSeedUsecase();
    getSettings = _MockGetSettingsUsecase();
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
  });

  group('DeriveNextBip85MnemonicFromDefaultWalletUsecase', () {
    late DeriveNextBip85MnemonicFromDefaultWalletUsecase usecase;

    setUp(() {
      usecase = DeriveNextBip85MnemonicFromDefaultWalletUsecase(
        bip85Repository: bip85Repository,
        getDefaultSeedUsecase: getDefaultSeed,
        getSettingsUsecase: getSettings,
      );
    });

    test('maps a missing default wallet', () async {
      when(
        () => getDefaultSeed.execute(environment: Environment.mainnet),
      ).thenAnswer((_) async => const Err(DefaultSeedNotFoundFailure()));

      final result = await usecase.execute();

      expect(result, isA<Err<dynamic, Bip85Failure>>());
      expect((result as Err).failure, isA<Bip85NoDefaultWalletFailure>());
    });

    test('maps an ambiguous default wallet', () async {
      when(
        () => getDefaultSeed.execute(environment: Environment.mainnet),
      ).thenAnswer((_) async => const Err(DefaultSeedAmbiguousFailure()));

      final result = await usecase.execute();

      expect(result, isA<Err<dynamic, Bip85Failure>>());
      expect(
        (result as Err).failure,
        isA<Bip85DefaultWalletAmbiguousFailure>(),
      );
    });
  });

  group('DeriveNextBip85HexFromDefaultWalletUsecase', () {
    late DeriveNextBip85HexFromDefaultWalletUsecase usecase;

    setUp(() {
      usecase = DeriveNextBip85HexFromDefaultWalletUsecase(
        bip85Repository: bip85Repository,
        getDefaultSeedUsecase: getDefaultSeed,
        getSettingsUsecase: getSettings,
      );
    });

    test('maps a missing default wallet', () async {
      when(
        () => getDefaultSeed.execute(environment: Environment.mainnet),
      ).thenAnswer((_) async => const Err(DefaultSeedNotFoundFailure()));

      final result = await usecase.execute(length: 30);

      expect(result, isA<Err<dynamic, Bip85Failure>>());
      expect((result as Err).failure, isA<Bip85NoDefaultWalletFailure>());
    });

    test('sanitizes an unavailable default seed', () async {
      when(
        () => getDefaultSeed.execute(environment: Environment.mainnet),
      ).thenAnswer((_) async => const Err(DefaultSeedUnavailableFailure()));

      final result = await usecase.execute(length: 30);

      expect(result, isA<Err<dynamic, Bip85Failure>>());
      expect((result as Err).failure, isA<Bip85UnexpectedFailure>());
    });
  });

  group('FetchAllBip85DerivationsWithEntropyUsecase', () {
    late FetchAllBip85DerivationsWithEntropyUsecase usecase;

    setUp(() {
      usecase = FetchAllBip85DerivationsWithEntropyUsecase(
        bip85Repository: bip85Repository,
        getDefaultSeedUsecase: getDefaultSeed,
        getSettingsUsecase: getSettings,
      );
    });

    test('sanitizes a default-wallet lookup failure', () async {
      when(
        () => getDefaultSeed.execute(environment: Environment.mainnet),
      ).thenAnswer((_) async => const Err(DefaultSeedWalletLookupFailure()));

      final result = await usecase.execute();

      expect(result, isA<Err<dynamic, Bip85Failure>>());
      expect((result as Err).failure, isA<Bip85UnexpectedFailure>());
    });
  });
}
