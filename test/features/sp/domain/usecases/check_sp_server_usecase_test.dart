import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/check_sp_server_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_backend_config_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../sp_fakes.dart';

class _MockLoadConfig extends Mock implements LoadSpBackendConfigUsecase {}

class _MockGetDefaults extends Mock implements GetSpBackendDefaultsUsecase {}

class _MockTestBackend extends Mock implements TestSpBackendUsecase {}

void main() {
  const network = BitcoinNetwork.mainnet;
  const kind = SpBackendKind.blindbit;
  const defaultUrl = 'https://blindbit.bullbitcoin.com';
  const customUrl = 'https://custom.example';
  late _MockLoadConfig loadConfig;
  late _MockGetDefaults getDefaults;
  late _MockTestBackend testBackend;
  late CheckSpServerUsecase usecase;

  setUp(() {
    loadConfig = _MockLoadConfig();
    getDefaults = _MockGetDefaults();
    testBackend = _MockTestBackend();
    usecase = CheckSpServerUsecase(
      loadConfig: loadConfig,
      getDefaults: getDefaults,
      testBackend: testBackend,
    );
  });

  test(
    'checks the configured BlindBit server for the active network',
    () async {
      when(loadConfig.execute).thenAnswer(
        (_) async =>
            Ok(spBackendConfig(network: network, blindbitUrl: customUrl)),
      );
      when(() => testBackend.execute(kind, customUrl))
          .thenAnswer((_) async => const Ok(null));

      expect(await usecase.execute(network), isA<Ok<void, SpFailure>>());
      verify(() => testBackend.execute(kind, customUrl)).called(1);
      verifyZeroInteractions(getDefaults);
    },
  );

  test(
    'uses the default when a saved backend is for another network',
    () async {
      when(loadConfig.execute).thenAnswer((_) async => Ok(spBackendConfig()));
      when(() => getDefaults.execute(network)).thenAnswer(
        (_) async => const Ok(
          SpBackendDefaults(blindbitUrl: defaultUrl, electrumUrl: 'unused'),
        ),
      );
      const failure = SpBackendUnreachable();
      when(() => testBackend.execute(kind, defaultUrl))
          .thenAnswer((_) async => const Err(failure));

      expect(
        await usecase.execute(network),
        const Err<void, SpFailure>(failure),
      );
      verify(() => testBackend.execute(kind, defaultUrl)).called(1);
    },
  );
}
