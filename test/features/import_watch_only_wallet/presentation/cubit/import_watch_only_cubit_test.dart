import 'dart:async';

import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockImportDescriptorUsecase extends Mock
    implements ImportWatchOnlyDescriptorUsecase {}

class _MockImportXpubUsecase extends Mock
    implements ImportWatchOnlyXpubUsecase {}

class _MockParseWatchOnlyInputUsecase extends Mock
    implements ParseWatchOnlyInputUsecase {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

const _xpub =
    'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';

void main() {
  test('rejects a wallet from another network before import', () async {
    final importXpub = _MockImportXpubUsecase();
    final settings = _MockSettingsRepository();
    final wallet = WatchOnlyWalletEntity.xpub(
      extendedPublicKey: _xpub,
      canonicalXpub: _xpub,
      network: Network.bitcoinTestnet,
      scriptType: ScriptType.bip84,
      label: 'Test wallet',
    );
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    final cubit = ImportWatchOnlyCubit(
      watchOnlyWallet: wallet,
      importWatchOnlyDescriptorUsecase: _MockImportDescriptorUsecase(),
      importWatchOnlyXpubUsecase: importXpub,
      parseWatchOnlyInputUsecase: _MockParseWatchOnlyInputUsecase(),
      settingsRepository: settings,
    );

    await cubit.import();

    expect(cubit.state.failure, isA<NetworkMismatchFailure>());

    await cubit.close();
  });

  test('reports invalid completed input', () async {
    const input = 'not a wallet';
    final parse = _MockParseWatchOnlyInputUsecase();
    when(
      () => parse.execute(input, signerDevice: null),
    ).thenAnswer((_) async => const Err(InvalidFormatFailure()));
    final cubit = ImportWatchOnlyCubit(
      importWatchOnlyDescriptorUsecase: _MockImportDescriptorUsecase(),
      importWatchOnlyXpubUsecase: _MockImportXpubUsecase(),
      parseWatchOnlyInputUsecase: parse,
      settingsRepository: _MockSettingsRepository(),
    );

    await cubit.parseInput(input);

    expect(cubit.state.failure, isA<InvalidFormatFailure>());
    verify(() => parse.execute(input, signerDevice: null)).called(1);

    await cubit.close();
  });

  test('clears a parse failure when valid input is retried', () async {
    final parse = _MockParseWatchOnlyInputUsecase();
    final wallet = WatchOnlyWalletEntity.xpub(
      extendedPublicKey: _xpub,
      canonicalXpub: _xpub,
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
    );
    var attempts = 0;
    when(() => parse.execute(_xpub, signerDevice: null)).thenAnswer((_) async {
      attempts++;
      return attempts == 1 ? const Err(InvalidFormatFailure()) : Ok(wallet);
    });
    final cubit = ImportWatchOnlyCubit(
      importWatchOnlyDescriptorUsecase: _MockImportDescriptorUsecase(),
      importWatchOnlyXpubUsecase: _MockImportXpubUsecase(),
      parseWatchOnlyInputUsecase: parse,
      settingsRepository: _MockSettingsRepository(),
    );

    await cubit.parseInput(_xpub);
    expect(cubit.state.failure, isA<InvalidFormatFailure>());

    await cubit.parseInput(_xpub);
    expect(cubit.state.failure, isNull);
    expect(cubit.state.watchOnlyWallet, wallet);

    await cubit.close();
  });

  test('ignores a stale parse result after a newer input succeeds', () async {
    final parse = _MockParseWatchOnlyInputUsecase();
    final firstResult =
        Completer<Result<WatchOnlyWalletEntity, ImportWatchOnlyFailure>>();
    final secondResult =
        Completer<Result<WatchOnlyWalletEntity, ImportWatchOnlyFailure>>();
    final firstWallet = WatchOnlyWalletEntity.xpub(
      extendedPublicKey: _xpub,
      canonicalXpub: _xpub,
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
      label: 'first',
    );
    final secondInput = _xpub.replaceFirst('xpub', 'ypub');
    final secondWallet = WatchOnlyWalletEntity.xpub(
      extendedPublicKey: secondInput,
      canonicalXpub: _xpub,
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
      label: 'second',
    );
    when(
      () => parse.execute(_xpub, signerDevice: null),
    ).thenAnswer((_) => firstResult.future);
    when(
      () => parse.execute(secondInput, signerDevice: null),
    ).thenAnswer((_) => secondResult.future);
    final cubit = ImportWatchOnlyCubit(
      importWatchOnlyDescriptorUsecase: _MockImportDescriptorUsecase(),
      importWatchOnlyXpubUsecase: _MockImportXpubUsecase(),
      parseWatchOnlyInputUsecase: parse,
      settingsRepository: _MockSettingsRepository(),
    );

    final firstParse = cubit.parseInput(_xpub);
    final secondParse = cubit.parseInput(secondInput);
    secondResult.complete(Ok(secondWallet));
    await secondParse;
    firstResult.complete(Ok(firstWallet));
    await firstParse;

    expect(cubit.state.input, secondInput);
    expect(cubit.state.watchOnlyWallet, secondWallet);

    await cubit.close();
  });
}
