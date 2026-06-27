import 'package:bb_mobile/core/mempool/application/dtos/requests/delete_custom_mempool_server_request.dart';
import 'package:bb_mobile/core/mempool/application/dtos/requests/load_mempool_server_data_request.dart';
import 'package:bb_mobile/core/mempool/application/dtos/requests/set_custom_mempool_server_request.dart';
import 'package:bb_mobile/core/mempool/application/dtos/requests/update_mempool_settings_request.dart';
import 'package:bb_mobile/core/mempool/application/usecases/delete_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/load_mempool_server_data_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/set_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/update_mempool_settings_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockServerRepository extends Mock implements MempoolServerRepository {}

class _MockSettingsRepository extends Mock
    implements MempoolSettingsRepository {}

class _MockValidator extends Mock implements MempoolServerValidatorPort {}

class _MockEnvironmentPort extends Mock implements MempoolEnvironmentPort {}

void main() {
  setUpAll(() {
    registerFallbackValue(MempoolServerNetwork.bitcoinMainnet);
    registerFallbackValue(
      MempoolServer.existing(
        url: 'mempool.example.com',
        network: MempoolServerNetwork.bitcoinMainnet,
        isCustom: true,
      ),
    );
    registerFallbackValue(
      MempoolSettings.existing(
        network: MempoolServerNetwork.bitcoinMainnet,
        useForFeeEstimation: true,
      ),
    );
  });

  group('DeleteCustomMempoolServerUsecase', () {
    late _MockServerRepository repo;
    late _MockEnvironmentPort env;
    late DeleteCustomMempoolServerUsecase usecase;

    setUp(() {
      repo = _MockServerRepository();
      env = _MockEnvironmentPort();
      usecase = DeleteCustomMempoolServerUsecase(
        serverRepository: repo,
        environmentPort: env,
      );
      when(() => env.getEnvironment()).thenAnswer((_) async => const Ok(Environment.mainnet));
    });

    test('propagates the sanitized delete failure', () async {
      when(() => repo.deleteCustomServer(any())).thenAnswer(
        (_) async => const Err(MempoolDeleteFailure('raw db error')),
      );

      final result = await usecase.execute(
        DeleteCustomMempoolServerRequest(isLiquid: false),
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolDeleteFailure>());
    });

    test('propagates an environment failure', () async {
      when(() => env.getEnvironment()).thenAnswer(
        (_) async => const Err(MempoolUnexpectedFailure('raw env error')),
      );

      final result = await usecase.execute(
        DeleteCustomMempoolServerRequest(isLiquid: false),
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolUnexpectedFailure>());
    });
  });

  group('SetCustomMempoolServerUsecase', () {
    late _MockServerRepository repo;
    late _MockValidator validator;
    late _MockEnvironmentPort env;
    late SetCustomMempoolServerUsecase usecase;

    SetCustomMempoolServerRequest request() => SetCustomMempoolServerRequest(
      url: 'mempool.example.com',
      isLiquid: false,
    );

    setUp(() {
      repo = _MockServerRepository();
      validator = _MockValidator();
      env = _MockEnvironmentPort();
      usecase = SetCustomMempoolServerUsecase(
        serverRepository: repo,
        validator: validator,
        environmentPort: env,
      );
      when(() => env.getEnvironment()).thenAnswer((_) async => const Ok(Environment.mainnet));
      // Default fetch fails → use-case folds it to null → comparison skipped.
      when(() => repo.fetchDefaultServer(any())).thenAnswer(
        (_) async => const Err(MempoolLoadFailure()),
      );
    });

    test('propagates the validation failure as a typed variant', () async {
      when(
        () => validator.validateServer(
          url: any(named: 'url'),
          network: any(named: 'network'),
          enableSsl: any(named: 'enableSsl'),
        ),
      ).thenAnswer(
        (_) async => const Err(MempoolValidationTimeoutFailure()),
      );

      final result = await usecase.execute(request());

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolValidationTimeoutFailure>());
      verifyNever(() => repo.save(any()));
    });

    test('returns InvalidUrl failure for a malformed URL', () async {
      final result = await usecase.execute(
        SetCustomMempoolServerRequest(url: 'no-dot-host', isLiquid: false),
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolInvalidUrlFailure>());
      verifyNever(() => repo.save(any()));
      verifyNever(
        () => validator.validateServer(
          url: any(named: 'url'),
          network: any(named: 'network'),
          enableSsl: any(named: 'enableSsl'),
        ),
      );
    });

    test('propagates the save failure when persisting fails', () async {
      when(
        () => validator.validateServer(
          url: any(named: 'url'),
          network: any(named: 'network'),
          enableSsl: any(named: 'enableSsl'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(() => repo.save(any())).thenAnswer(
        (_) async => const Err(MempoolSaveFailure('raw db error')),
      );

      final result = await usecase.execute(request());

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolSaveFailure>());
    });

    test('returns SameAsDefault failure when custom URL matches the default',
        () async {
      // Return the same URL as the one in request() so the comparison triggers.
      when(() => repo.fetchDefaultServer(any())).thenAnswer(
        (_) async => Ok(
          MempoolServer.existing(
            url: 'mempool.example.com',
            network: MempoolServerNetwork.bitcoinMainnet,
            isCustom: false,
          ),
        ),
      );

      final result = await usecase.execute(request());

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolServerSameAsDefaultFailure>());
      verifyNever(() => repo.save(any()));
    });
  });

  group('LoadMempoolServerDataUsecase', () {
    late _MockServerRepository repo;
    late _MockSettingsRepository settingsRepo;
    late _MockEnvironmentPort env;
    late LoadMempoolServerDataUsecase usecase;

    final defaultServer = MempoolServer.existing(
      url: 'mempool.space',
      network: MempoolServerNetwork.bitcoinMainnet,
      isCustom: false,
    );

    setUp(() {
      repo = _MockServerRepository();
      settingsRepo = _MockSettingsRepository();
      env = _MockEnvironmentPort();
      usecase = LoadMempoolServerDataUsecase(
        serverRepository: repo,
        settingsRepository: settingsRepo,
        environmentPort: env,
      );
      when(() => env.getEnvironment())
          .thenAnswer((_) async => const Ok(Environment.mainnet));
    });

    test('propagates the failure when fetchDefaultServer fails', () async {
      when(() => repo.fetchDefaultServer(any())).thenAnswer(
        (_) async => const Err(MempoolLoadFailure('raw db error')),
      );
      when(() => repo.fetchCustomServer(any()))
          .thenAnswer((_) async => const Ok(null));
      when(() => settingsRepo.fetchByNetwork(any())).thenAnswer(
        (_) async => const Err(MempoolLoadFailure()),
      );

      final result = await usecase.execute(
        LoadMempoolServerDataRequest(isLiquid: false),
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolLoadFailure>());
    });

    test('propagates the failure when fetchCustomServer fails', () async {
      when(() => repo.fetchDefaultServer(any()))
          .thenAnswer((_) async => Ok(defaultServer));
      when(() => repo.fetchCustomServer(any())).thenAnswer(
        (_) async => const Err(MempoolLoadFailure('custom server error')),
      );
      when(() => settingsRepo.fetchByNetwork(any())).thenAnswer(
        (_) async => const Err(MempoolLoadFailure()),
      );

      final result = await usecase.execute(
        LoadMempoolServerDataRequest(isLiquid: false),
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolLoadFailure>());
    });

    test('propagates the failure when fetchByNetwork (settings) fails',
        () async {
      when(() => repo.fetchDefaultServer(any()))
          .thenAnswer((_) async => Ok(defaultServer));
      when(() => repo.fetchCustomServer(any()))
          .thenAnswer((_) async => const Ok(null));
      when(() => settingsRepo.fetchByNetwork(any())).thenAnswer(
        (_) async => const Err(MempoolLoadFailure('settings error')),
      );

      final result = await usecase.execute(
        LoadMempoolServerDataRequest(isLiquid: false),
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolLoadFailure>());
    });
  });

  group('UpdateMempoolSettingsUsecase', () {
    test('propagates the load failure when fetching current settings', () async {
      final settingsRepo = _MockSettingsRepository();
      final env = _MockEnvironmentPort();
      final usecase = UpdateMempoolSettingsUsecase(
        settingsRepository: settingsRepo,
        environmentPort: env,
      );
      when(() => env.getEnvironment()).thenAnswer((_) async => const Ok(Environment.mainnet));
      when(() => settingsRepo.fetchByNetwork(any())).thenAnswer(
        (_) async => const Err(MempoolLoadFailure('raw db error')),
      );

      final result = await usecase.execute(
        UpdateMempoolSettingsRequest(isLiquid: false, useForFeeEstimation: true),
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolLoadFailure>());
    });

    test('propagates the save failure when persisting settings fails', () async {
      final settingsRepo = _MockSettingsRepository();
      final env = _MockEnvironmentPort();
      final usecase = UpdateMempoolSettingsUsecase(
        settingsRepository: settingsRepo,
        environmentPort: env,
      );
      when(() => env.getEnvironment()).thenAnswer(
        (_) async => const Ok(Environment.mainnet),
      );
      when(() => settingsRepo.fetchByNetwork(any())).thenAnswer(
        (_) async => Ok(
          MempoolSettings.existing(
            network: MempoolServerNetwork.bitcoinMainnet,
            useForFeeEstimation: false,
          ),
        ),
      );
      when(() => settingsRepo.save(any())).thenAnswer(
        (_) async => const Err(MempoolSaveFailure('raw db error')),
      );

      final result = await usecase.execute(
        UpdateMempoolSettingsRequest(isLiquid: false, useForFeeEstimation: true),
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<MempoolSaveFailure>());
    });
  });
}
