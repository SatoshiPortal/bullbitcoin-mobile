import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:wallet_import/src/domain/watch_only/import_watch_only_descriptor_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/import_watch_only_xpub_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/parse_watch_only_input_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/read_watch_only_network_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
import 'package:wallet_import/src/presentation/watch_only/import_watch_only_cubit.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:preferences/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class _Settings extends Mock implements ActiveEnvironmentReader {}

class _ImportXpub extends Mock implements ImportWatchOnlyXpubUsecase {}

class _ImportDescriptor extends Mock
    implements ImportWatchOnlyDescriptorUsecase {}

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
          .thenAnswer((_) async => Ok(Environment.regtest));
      final importer = _ImportXpub();

      when(() => importer.execute(watchOnlyXpub: any(named: 'watchOnlyXpub')))
          .thenAnswer((_) async => const Ok(null));
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
      expect(cubit.state.imported, isTrue);
      final captured =
          verify(
                () => importer.execute(
                  watchOnlyXpub: captureAny(named: 'watchOnlyXpub'),
                ),
              ).captured.single
              as WatchOnlyXpubEntity;
      expect(captured.network, BitcoinNetwork.regtest);
      expect(captured.pubkey, _vpub);
    },
  );
}
