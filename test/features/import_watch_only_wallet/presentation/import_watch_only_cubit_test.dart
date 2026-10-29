import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/validate_watch_only_import_usecase.dart';
import 'dart:async';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class _MockImportWatchOnlyDescriptorUsecase extends Mock
    implements ImportWatchOnlyDescriptorUsecase {}

class _MockImportWatchOnlyXpubUsecase extends Mock
    implements ImportWatchOnlyXpubUsecase {}

class _MockParseWatchOnlyInputUsecase extends Mock
    implements ParseWatchOnlyInputUsecase {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWatchOnlyDescriptor extends Mock
    implements satoshifier.WatchOnlyDescriptor {}

class _MockDescriptor extends Mock implements satoshifier.Descriptor {}

class _MockXpub extends Mock implements satoshifier.WatchOnlyXpub {}

class _MockExtendedPubkey extends Mock implements satoshifier.ExtendedPubkey {}

void main() {
  for (final descriptorInput in [true, false]) {
    test(
      'forwards private source and birthday for ${descriptorInput ? 'descriptor' : 'xpub'}',
      () async {
        final WatchOnlyWalletEntity wallet;
        if (descriptorInput) {
          final descriptor = _MockDescriptor();
          when(
            () => descriptor.network,
          ).thenReturn(satoshifier.Network.bitcoinMainnet);
          final key = _MockWatchOnlyDescriptor();
          when(() => key.descriptor).thenReturn(descriptor);
          wallet = WatchOnlyDescriptorEntity(
            watchOnlyDescriptor: key,
            label: 'Public descriptor',
          );
        } else {
          final publicKey = _MockExtendedPubkey();
          when(
            () => publicKey.network,
          ).thenReturn(satoshifier.Network.bitcoinMainnet);
          final key = _MockXpub();
          when(() => key.extendedPubkey).thenReturn(publicKey);
          wallet = WatchOnlyXpubEntity(
            watchOnlyXpub: key,
            label: 'Public xpub',
          );
        }
        final settings = _MockSettingsRepository();
        when(() => settings.fetch()).thenAnswer(
          (_) async => const SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        );
        final descriptor = _MockImportWatchOnlyDescriptorUsecase();
        final xpub = _MockImportWatchOnlyXpubUsecase();
        final birthday = WalletBirthday(DateTime.utc(2021, 3));
        if (wallet case final WatchOnlyDescriptorEntity selected) {
          when(
            () => descriptor.execute(
              watchOnlyDescriptor: selected,
              birthday: birthday,
              bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
            ),
          ).thenAnswer((_) async => const Err(ImportFailedFailure()));
        } else if (wallet case final WatchOnlyXpubEntity selected) {
          when(
            () => xpub.execute(
              watchOnlyXpub: selected,
              birthday: birthday,
              bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
            ),
          ).thenAnswer((_) async => const Err(ImportFailedFailure()));
        }
        final cubit = ImportWatchOnlyCubit(
          watchOnlyWallet: wallet,
          importWatchOnlyDescriptorUsecase: descriptor,
          importWatchOnlyXpubUsecase: xpub,
          parseWatchOnlyInputUsecase: _MockParseWatchOnlyInputUsecase(),
          validateImport: ValidateWatchOnlyImportUsecase(settings: settings),
        );
        addTearDown(cubit.close);
        await cubit.import(
          birthday: birthday,
          bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
        );
        expect(cubit.state.failure, isA<ImportFailedFailure>());
        if (wallet case final WatchOnlyDescriptorEntity selected) {
          verify(
            () => descriptor.execute(
              watchOnlyDescriptor: selected,
              birthday: birthday,
              bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
            ),
          ).called(1);
          verifyZeroInteractions(xpub);
        } else if (wallet case final WatchOnlyXpubEntity selected) {
          verify(
            () => xpub.execute(
              watchOnlyXpub: selected,
              birthday: birthday,
              bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
            ),
          ).called(1);
          verifyZeroInteractions(descriptor);
        }
      },
    );
  }

  test(
    'changing input during local settings read prevents importing the old wallet',
    () async {
      final descriptor = _MockWatchOnlyDescriptor();
      final key = _MockDescriptor();
      when(() => key.network).thenReturn(satoshifier.Network.bitcoinMainnet);
      when(() => descriptor.descriptor).thenReturn(key);
      final wallet = WatchOnlyDescriptorEntity(
        watchOnlyDescriptor: descriptor,
        label: 'Public fixture',
      );
      final settings = _MockSettingsRepository();
      final pending = Completer<SettingsEntity>();
      when(() => settings.fetch()).thenAnswer((_) => pending.future);
      final importDescriptor = _MockImportWatchOnlyDescriptorUsecase();
      final cubit = ImportWatchOnlyCubit(
        watchOnlyWallet: wallet,
        importWatchOnlyDescriptorUsecase: importDescriptor,
        importWatchOnlyXpubUsecase: _MockImportWatchOnlyXpubUsecase(),
        parseWatchOnlyInputUsecase: _MockParseWatchOnlyInputUsecase(),
        validateImport: ValidateWatchOnlyImportUsecase(settings: settings),
      );
      addTearDown(cubit.close);
      final pendingImport = cubit.import(
        bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
      );
      await cubit.parsePastedInput('');
      cubit.updateLabel('Ignored');
      cubit.onSignerChanged(SignerEntity.none);
      cubit.onSignerDeviceChanged(null);
      cubit.onDerivationChanged(satoshifier.Derivation.bip84);
      pending.complete(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      await pendingImport;
      expect(cubit.state.watchOnlyWallet, isNull);
      verifyZeroInteractions(importDescriptor);
    },
  );

  test('rejects a watch-only wallet from the inactive environment', () async {
    final descriptor = _MockDescriptor();
    when(
      () => descriptor.network,
    ).thenReturn(satoshifier.Network.bitcoinMainnet);
    final watchOnlyDescriptor = _MockWatchOnlyDescriptor();
    when(() => watchOnlyDescriptor.descriptor).thenReturn(descriptor);
    final wallet = WatchOnlyDescriptorEntity(
      watchOnlyDescriptor: watchOnlyDescriptor,
      label: 'SeedSigner',
    );
    final importDescriptor = _MockImportWatchOnlyDescriptorUsecase();
    final settings = _MockSettingsRepository();
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    final cubit = ImportWatchOnlyCubit(
      watchOnlyWallet: wallet,
      importWatchOnlyDescriptorUsecase: importDescriptor,
      importWatchOnlyXpubUsecase: _MockImportWatchOnlyXpubUsecase(),
      parseWatchOnlyInputUsecase: _MockParseWatchOnlyInputUsecase(),
      validateImport: ValidateWatchOnlyImportUsecase(settings: settings),
    );
    addTearDown(cubit.close);

    await cubit.import();

    expect(cubit.state.failure, isA<NetworkMismatchFailure>());
    verifyNever(() => importDescriptor.execute(watchOnlyDescriptor: wallet));
  });
}
