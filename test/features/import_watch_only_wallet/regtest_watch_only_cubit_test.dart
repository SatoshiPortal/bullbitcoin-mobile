import 'package:bb_mobile/features/import_watch_only_wallet/read_watch_only_network_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class _Settings extends Mock implements ActiveEnvironmentReader {}

class _ImportXpub extends Mock implements ImportWatchOnlyXpubUsecase {}

class _ImportDescriptor extends Mock
    implements ImportWatchOnlyDescriptorUsecase {}

class _Wallet extends Mock implements Wallet {}

const _vpub =
    'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc';

void main() {
  setUpAll(
    () => registerFallbackValue(
      WatchOnlyXpubEntity(
        watchOnlyXpub: satoshifier.WatchOnlyXpub(
          extendedPubkey: satoshifier.ExtendedPubkey.parse(_vpub),
        ),
      ),
    ),
  );

  test(
    'a real parsed test public key imports in the selected regtest context',
    () async {
      final settings = _Settings();
      when(settings.readActiveEnvironment)
          .thenAnswer((_) async => Environment.regtest);
      final importer = _ImportXpub();
      final imported = _Wallet();
      when(() => imported.network).thenReturn(Network.bitcoinRegtest);
      when(() => importer.execute(watchOnlyXpub: any(named: 'watchOnlyXpub')))
          .thenAnswer((_) async => Ok(imported));
      final cubit = ImportWatchOnlyCubit(
        importWatchOnlyXpubUsecase: importer,
        importWatchOnlyDescriptorUsecase: _ImportDescriptor(),
        parseWatchOnlyInputUsecase: ParseWatchOnlyInputUsecase(),
        readNetworkUsecase: ReadWatchOnlyNetworkUsecase(settings),
      );
      addTearDown(cubit.close);
      await cubit.parsePastedInput(_vpub);
      cubit.updateLabel('Public regtest account');
      await cubit.import();
      expect(cubit.state.failure, isNull);
      expect(cubit.state.importedWallet, same(imported));
      final captured =
          verify(
                () => importer.execute(
                  watchOnlyXpub: captureAny(named: 'watchOnlyXpub'),
                ),
              ).captured.single
              as WatchOnlyXpubEntity;
      expect(captured.network, Network.bitcoinRegtest);
      expect(captured.pubkey, _vpub);
    },
  );
}
