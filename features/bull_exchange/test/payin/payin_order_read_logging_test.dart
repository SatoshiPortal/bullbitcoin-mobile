import 'dart:io';
import 'dart:typed_data';

import 'package:bbx_api/bbx_api_testing.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/payin_spend_calls.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:dio/dio.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/labels.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

const _host = 'private-refresh.invalid';
const _orderId = 'private-order-sentinel';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 0,
  sessionId: 'session',
);

/// Throws [error] for every request, counting them.
class _Throwing implements HttpClientAdapter {
  final Object error;
  final List<RequestOptions> requests = [];

  _Throwing(this.error);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    throw error;
  }

  @override
  void close({bool force = false}) {}
}

/// Records what reaches the crash reporter.
class _Reporter implements LoggerReporter {
  final reports = <String>[];

  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) => reports.add('$message | $exception | $stackTrace');

  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) async => reports.add('$message | $exception | $stackTrace');
}

class _Spend extends Mock implements Spend {}

class _Fees extends Mock implements Fees {}

class _PayjoinPolicy extends Mock implements PayjoinPolicyAccess {}

class _PayjoinSender extends Mock implements PayjoinSender {}

class _PayjoinSessions extends Mock implements PayjoinSessions {}

class _Labels extends Mock implements Labels {}

Exchange _exchange(HttpClientAdapter adapter) =>
    exchangeWithTransportForTesting(
      readSession: () async => const Ok((
        environment: ExchangeEnvironment.mainnet,
        epoch: 0,
        apiKey: 'k',
      )),
      openClient: (endpoint, readKey) => bbxForTesting(
        endpoint: endpoint.toString(),
        adapter: adapter,
        readActiveApiKey: readKey,
      ),
    );

void main() {
  // Sell and pay read their order after the payin broadcast (recheck,
  // verify, receipt) through the same PayinUsecases.getOrder.
  test('a failed post-broadcast order read keeps foreign text out of disk logs '
      'and the reporter', () async {
    const socket = SocketException("Failed host lookup: '$_host'");
    // Same native SocketException -> DioException conversion as Dio's IO
    // adapter.
    final cause = DioException.connectionError(
      requestOptions: RequestOptions(
        baseUrl: 'https://$_host',
        path: '/ak/api-orders',
      ),
      reason: socket.message,
      error: socket,
    );
    final directory = await Directory.systemTemp.createTemp(
      'payin-order-read-',
    );
    final reporter = _Reporter();
    log = Logger.replace(directory: directory, reporter: reporter);
    addTearDown(() async {
      await log.flush();
      log = Logger.replace(directory: Directory.current);
      await directory.delete(recursive: true);
    });
    final transport = _Throwing(cause);
    final PayinWalletServices services = (
      spend: _Spend(),
      fees: _Fees(),
      payjoinPolicy: _PayjoinPolicy(),
      payjoinSender: _PayjoinSender(),
      payjoinSessions: _PayjoinSessions(),
      labels: _Labels(),
      coins: (_) async => null,
    );
    final payin = PayinUsecases.of(_exchange(transport), services);

    final read = await payin.getOrder.execute(_session, _orderId);

    expect(
      read,
      isA<Err<Order, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeUnreachableFailure>().having(
          (r) => r.isNetwork,
          'isNetwork',
          isTrue,
        ),
      ),
    );
    expect(transport.requests, hasLength(1));
    expect(
      transport.requests.single.data.toString(),
      contains(_orderId),
      reason: 'the read asks for the order; only the logs must not name it',
    );
    await log.flush();
    // The read path may log nothing at all; whatever it logs must be safe.
    final disk = await log.logsFile.exists()
        ? await log.logsFile.readAsString()
        : '';
    expect(
      ((read as Err<Order, ExchangeReadFailure>).failure
              as ExchangeUnreachableFailure)
          .reason,
      'ExchangeNetworkFailure',
    );
    final diagnostics = '$disk\n${reporter.reports.join('\n')}\n$read';
    for (final sentinel in [
      _host,
      _orderId,
      'DioException',
      'SocketException',
      'Failed host lookup',
    ]) {
      expect(diagnostics, isNot(contains(sentinel)));
    }
  });
}
