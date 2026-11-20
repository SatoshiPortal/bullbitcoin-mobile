import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/features/exchange/domain/usecases/get_order_stats_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/upload_kyc_document_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_statistics_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/upload_exchange_document_usecase.dart';
import 'package:file_system/file_system.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bb_mobile/core/exchange/data/http/exchange_authentication_interceptor.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_order_repository.dart';
import 'package:bb_mobile/features/exchange_settings/data/bbx_api_kyc_repository.dart';
import 'package:bb_mobile/features/exchange_settings/data/bbx_api_order_stats_repository.dart';
import 'package:bbx_api/bbx_api.dart' show BbxApiClient;
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/buy/domain/refresh_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:dio/dio.dart';
import 'package:bb_mobile/core/exchange/data/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/entity/exchange_api_key.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';

const _sensitive = 'synthetic-private-credential';

class _Settings extends Fake implements SettingsRepository {
  @override
  Future<SettingsEntity> fetch() async => const SettingsEntity(
    environment: Environment.testnet,
    bitcoinUnit: BitcoinUnit.btc,
    currencyCode: 'CAD',
  );
}

class _Picker extends Fake implements FileSystem {
  @override
  Future<Result<PickedDocument?, FileSystemFailure>> pick({
    List<String> allowedExtensions = const [],
  }) async => Ok(_Document());

  @override
  Future<Result<Uint8List, FileSystemFailure>> read(
    PickedDocument document, {
    required int maxBytes,
  }) async => Ok(Uint8List.fromList([1]));
}

class _Document extends Fake implements PickedDocument {
  @override
  String get name => 'synthetic.pdf';
  @override
  String get extension => 'pdf';
}

class _Reporter implements LoggerReporter {
  var calls = 0;
  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) {
    calls++;
  }

  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) async {
    calls++;
  }
}

ExchangeApiKey _credential() => switch (ExchangeApiKey.create(
  id: 'id',
  key: _sensitive,
  name: 'name',
  userId: 'user',
  isActive: true,
  createdAt: 0,
  updatedAt: 0,
)) {
  Ok(:final value) => value,
  Err() => throw StateError('Invalid synthetic fixture'),
};

void main() {
  late Directory directory;
  late _Reporter reporter;
  late FakeSecureStoragePlatform storage;
  late ExchangeApiKeyRepositoryImpl repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'credential-diagnostics-',
    );
    reporter = _Reporter();
    log = Logger.replace(directory: directory, reporter: reporter);
    storage = FakeSecureStoragePlatform().install();
    repository = ExchangeApiKeyRepositoryImpl(
      secureStorage: Secrets(scratchDirectory: () async => '/tmp')
          .exchangeKeychain,
    );
  });
  tearDown(() async {
    await log.flush();
    await directory.delete(recursive: true);
  });

  test(
    'an order action refuses unavailable credentials without reporting',
    () async {
      storage.scripted.add(Exception(_sensitive));
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
      addTearDown(() => dio.close(force: true));
      addExchangeAuthentication(
        dio,
        () => repository.readActiveApiKey(isTestnet: true),
      );
      final orders = BbxApiOrderRepository(
        api: BbxApiClient(dio),
        isTestnet: true,
      );
      final operation = RefreshBuyOrderUsecase(
        mainnetExchangeOrderRepository: orders,
        testnetExchangeOrderRepository: orders,
        settingsRepository: _Settings(),
      );
      final result = await operation.execute(orderId: 'synthetic-order');
      expect(
        result,
        isA<Err<dynamic, BuyFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<BuyUnexpectedFailure>(),
        ),
      );
      expect(reporter.calls, 0);
    },
  );

  test('statistics credential refusal never invokes the reporter', () async {
    storage.scripted.add(Exception(_sensitive));
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
    addTearDown(() => dio.close(force: true));
    addExchangeAuthentication(
      dio,
      () => repository.readActiveApiKey(isTestnet: true),
    );
    final stats = BbxApiOrderStatsRepository(api: BbxApiClient(dio));
    final operation = GetExchangeStatisticsUsecase(
      getOrderStatsUsecase: GetOrderStatsUsecase(
        mainnetRepository: stats,
        testnetRepository: stats,
        settingsRepository: _Settings(),
      ),
    );
    expect(
      await operation.execute(),
      isA<Err<dynamic, ExchangeSettingsFailure>>(),
    );
    expect(reporter.calls, 0);
  });

  test('document credential refusal never invokes the reporter', () async {
    storage.scripted.add(Exception(_sensitive));
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
    addTearDown(() => dio.close(force: true));
    addExchangeAuthentication(
      dio,
      () => repository.readActiveApiKey(isTestnet: true),
    );
    final kyc = BbxApiKycRepository(api: BbxApiClient(dio));
    final operation = UploadExchangeDocumentUsecase(
      fileSystem: _Picker(),
      uploadKycDocumentUsecase: UploadKycDocumentUsecase(
        mainnetRepository: kyc,
        testnetRepository: kyc,
        settingsRepository: _Settings(),
      ),
    );
    expect(
      await operation.execute(),
      isA<Err<dynamic, ExchangeSettingsFailure>>(),
    );
    expect(reporter.calls, 0);
  });

  for (final invalidJson in [false, true]) {
    test(
      '${invalidJson ? 'corrupt' : 'inaccessible'} storage logs one failure and one recovery',
      () async {
        if (invalidJson) {
          storage.entries['exchange_api_key_testnet'] =
              '{"key":"$_sensitive", malformed';
        } else {
          storage.scripted.addAll(List.filled(3, Exception(_sensitive)));
        }
        for (var attempt = 0; attempt < 3; attempt++) {
          expect(
            await repository.readActiveApiKey(isTestnet: true) is Err,
            isTrue,
          );
        }
        storage.entries['exchange_api_key_testnet'] = jsonEncode({
          'key': _sensitive,
          'isActive': true,
        });
        for (var attempt = 0; attempt < 2; attempt++) {
          expect(
            await repository.readActiveApiKey(isTestnet: true) is Ok,
            isTrue,
          );
        }
        final rows = (await log.readLogs())
            .map((line) => line.split('\t'))
            .toList();
        expect(rows.where((row) => row[1] == 'WARNING').length, 1);
        expect(rows.where((row) => row[1] == 'FINE').length, 1);
        expect(rows.toString(), isNot(contains(_sensitive)));
        expect(reporter.calls, 0);
      },
    );
  }

  test('read diagnostics remain independent for both environments', () async {
    storage.scripted.addAll(List.filled(4, Exception(_sensitive)));
    for (final environment in [false, true, false, true]) {
      expect(
        await repository.readActiveApiKey(isTestnet: environment) is Err,
        isTrue,
      );
    }
    final rows = (await log.readLogs())
        .map((line) => line.split('\t'))
        .toList();
    expect(rows.where((row) => row[1] == 'WARNING').length, 2);
    expect(reporter.calls, 0);
  });

  test('recoverable write and delete failures persist without invoking the reporter', () async {
    storage.scriptedWrites.addAll(List.filled(2, Exception(_sensitive)));
    expect(
      await repository.saveApiKey(_credential(), isTestnet: true) is Err,
      isTrue,
    );
    expect(await repository.deleteApiKey(isTestnet: true) is Err, isTrue);
    final rows = (await log.readLogs())
        .map((line) => line.split('\t'))
        .toList();
    expect(reporter.calls, 0);
    expect(rows.where((row) => row[1] == 'WARNING').length, 2);
    expect(rows.toString(), isNot(contains(_sensitive)));
  });
}
