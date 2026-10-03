import 'package:bb_mobile/core/settings/data/settings_repository.dart';
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

void main() {
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
      settingsRepository: settings,
    );
    addTearDown(cubit.close);

    await cubit.import();

    expect(cubit.state.failure, isA<NetworkMismatchFailure>());
    verifyNever(() => importDescriptor.execute(watchOnlyDescriptor: wallet));
  });
}
