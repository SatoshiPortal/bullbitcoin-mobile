import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bbx_api_test_http.dart';

const _sensitive = 'synthetic-private-credential';

class _Settings extends Fake implements Preferences {
  @override
  Future<Result<SettingsEntity, PreferencesFailure>> fetch() async => Ok(
    const SettingsEntity(
      environment: Environment.testnet,
      bitcoinUnit: BitcoinUnit.btc,
      currencyCode: 'CAD',
    ),
  );
}

/// Fails loudly if the transport is reached: a credential refusal stops the
/// request before the network.
class _NoRequest implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw StateError('No request expected');

  @override
  void close({bool force = false}) {}
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
  late InMemoryExchangeCredentialStorage storage;
  late ExchangeCredentials repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'credential-diagnostics-',
    );
    reporter = _Reporter();
    log = Logger.replace(directory: directory, reporter: reporter);
    storage = InMemoryExchangeCredentialStorage();
    repository = ExchangeCredentials.open(storage);
  });
  tearDown(() async {
    await log.flush();
    await directory.delete(recursive: true);
  });

  test(
    'an order action refuses unavailable credentials without reporting',
    () async {
      storage.scripted.add(Exception(_sensitive));
      final orders = testExchange(
        _NoRequest(),
        isTestnet: true,
        readApiKey: () => repository.readActiveApiKey(isTestnet: true),
      ).orders(ExchangeEnvironment.testnet);
      expect(
        await orders.refreshBuyOrder('synthetic-order'),
        isA<Err<BuyOrder, ExchangeFailure>>(),
      );
      expect(reporter.calls, 0);
    },
  );

  test('statistics credential refusal never invokes the reporter', () async {
    storage.scripted.add(Exception(_sensitive));
    final exchange = Exchange.open(
      mainnetEndpoint: Uri.parse(testBbxEndpoint),
      testnetEndpoint: Uri.parse(testBbxEndpoint),
      readSession: () => readLegacyExchangeSession(
        preferences: _Settings(),
        readSession: () => null,
        readKey: repository.readActiveApiKey,
      ),
    );
    expect(
      await exchange.getOrderStats(),
      isA<Err<OrderStatistics, ExchangeFailure>>(),
    );
    expect(reporter.calls, 0);
  });

  test('document credential refusal never invokes the reporter', () async {
    storage.scripted.add(Exception(_sensitive));
    final exchange = Exchange.open(
      mainnetEndpoint: Uri.parse(testBbxEndpoint),
      testnetEndpoint: Uri.parse(testBbxEndpoint),
      readSession: () => readLegacyExchangeSession(
        preferences: _Settings(),
        readSession: () => null,
        readKey: repository.readActiveApiKey,
      ),
    );
    expect(
      await exchange.uploadKycDocument(
        fileBytes: [1],
        fileName: 'synthetic.pdf',
      ),
      isA<Err<void, ExchangeFailure>>(),
    );
    expect(reporter.calls, 0);
  });

  for (final invalidJson in [false, true]) {
    test(
      '${invalidJson ? 'corrupt' : 'inaccessible'} storage logs one failure and one recovery',
      () async {
        if (invalidJson) {
          storage.entries['testnet'] = '{"key":"$_sensitive", malformed';
        } else {
          storage.scripted.addAll(List.filled(3, Exception(_sensitive)));
        }
        for (var attempt = 0; attempt < 3; attempt++) {
          expect(
            await repository.readActiveApiKey(isTestnet: true),
            isA<Err<String?, ExchangeFailure>>(),
          );
        }
        storage.entries['testnet'] = jsonEncode({
          'key': _sensitive,
          'isActive': true,
        });
        for (var attempt = 0; attempt < 2; attempt++) {
          expect(
            await repository.readActiveApiKey(isTestnet: true),
            isA<Ok<String?, ExchangeFailure>>(),
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
        await repository.readActiveApiKey(isTestnet: environment),
        isA<Err<String?, ExchangeFailure>>(),
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
      await repository.saveApiKey(_credential(), isTestnet: true),
      isA<Err<void, ExchangeFailure>>(),
    );
    expect(
      await repository.deleteApiKey(isTestnet: true),
      isA<Err<void, ExchangeFailure>>(),
    );
    final rows = (await log.readLogs())
        .map((line) => line.split('\t'))
        .toList();
    expect(reporter.calls, 0);
    expect(rows.where((row) => row[1] == 'WARNING').length, 2);
    expect(rows.toString(), isNot(contains(_sensitive)));
  });
}
