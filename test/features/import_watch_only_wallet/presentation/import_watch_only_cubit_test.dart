import 'package:bb_mobile/features/import_watch_only_wallet/read_watch_only_network_usecase.dart';
import 'package:preferences/preferences.dart';
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

class _MockActiveEnvironmentReader extends Mock
    implements ActiveEnvironmentReader {}

class _MockWatchOnlyDescriptor extends Mock
    implements satoshifier.WatchOnlyDescriptor {}

class _MockDescriptor extends Mock implements satoshifier.Descriptor {}

void main() {
  test('successful parsing clears a previous validation failure', () async {
    final settings = _MockActiveEnvironmentReader();
    when(() => settings.readActiveEnvironment())
        .thenAnswer((_) async => Environment.testnet);
    final cubit = ImportWatchOnlyCubit(
      importWatchOnlyDescriptorUsecase: _MockImportWatchOnlyDescriptorUsecase(),
      importWatchOnlyXpubUsecase: _MockImportWatchOnlyXpubUsecase(),
      parseWatchOnlyInputUsecase: ParseWatchOnlyInputUsecase(),
      readNetworkUsecase: ReadWatchOnlyNetworkUsecase(settings),
    );
    addTearDown(cubit.close);
    await cubit.import();
    expect(cubit.state.failure, isA<NoWalletSelectedFailure>());
    await cubit.parsePastedInput(
      'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc',
    );
    expect(cubit.state.watchOnlyWallet, isA<WatchOnlyXpubEntity>());
    expect(cubit.state.failure, isNull);
  });

  test('rejects a watch-only wallet from the inactive environment', () async {
    final descriptor = _MockDescriptor();
    when(() => descriptor.network)
        .thenReturn(satoshifier.Network.bitcoinMainnet);
    final watchOnlyDescriptor = _MockWatchOnlyDescriptor();
    when(() => watchOnlyDescriptor.descriptor).thenReturn(descriptor);
    final wallet = WatchOnlyDescriptorEntity(
      watchOnlyDescriptor: watchOnlyDescriptor,
      label: 'SeedSigner',
    );
    final importDescriptor = _MockImportWatchOnlyDescriptorUsecase();
    final settings = _MockActiveEnvironmentReader();
    when(() => settings.readActiveEnvironment())
        .thenAnswer((_) async => Environment.testnet);
    final cubit = ImportWatchOnlyCubit(
      watchOnlyWallet: wallet,
      importWatchOnlyDescriptorUsecase: importDescriptor,
      importWatchOnlyXpubUsecase: _MockImportWatchOnlyXpubUsecase(),
      parseWatchOnlyInputUsecase: _MockParseWatchOnlyInputUsecase(),
      readNetworkUsecase: ReadWatchOnlyNetworkUsecase(settings),
    );
    addTearDown(cubit.close);

    await cubit.import();

    expect(cubit.state.failure, isA<NetworkMismatchFailure>());
    verifyNever(() => importDescriptor.execute(watchOnlyDescriptor: wallet));
  });
}
