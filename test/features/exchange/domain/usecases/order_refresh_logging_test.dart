import 'dart:io';

import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_order_repository_impl.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/features/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_pay_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/load_sell_context_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Api extends Mock implements BullbitcoinApiDatasource {}

class _Keys extends Mock implements BullbitcoinApiKeyDatasource {}

class _Settings extends Mock implements SettingsRepository {}

class _Summary extends Mock implements GetExchangeUserSummaryUsecase {}

class _GetSettings extends Mock implements GetSettingsUsecase {}

class _Fees extends Mock implements GetNetworkFeesUsecase {}

class _Address extends Mock implements GetAddressAtIndexUsecase {}

class _Reporter extends Mock implements LoggerReporter {}

void main() {
  setUpAll(() => registerFallbackValue(StackTrace.empty));
  for (final feature in ['sell', 'pay']) {
    test(
      '$feature post-broadcast order refresh keeps foreign text out of disk and reporter',
      () async {
        const host = 'private-refresh.invalid';
        const orderId = 'private-order-sentinel';
        const socket = SocketException("Failed host lookup: '$host'");
        // Same native SocketException -> DioException conversion as Dio's IO adapter.
        final cause = DioException.connectionError(
          requestOptions: RequestOptions(
            baseUrl: 'https://$host',
            path: '/ak/api-orders',
          ),
          reason: socket.message,
          error: socket,
        );
        final directory = await Directory.systemTemp.createTemp(
          'sendlog-review-refresh-',
        );
        final reporter = _Reporter();
        log = Logger.replace(directory: directory, reporter: reporter);
        addTearDown(() async {
          await log.flush();
          log = Logger.replace(directory: Directory.current);
          await directory.delete(recursive: true);
        });
        final api = _Api();
        final keys = _Keys();
        final settings = _Settings();
        when(() => keys.get(isTestnet: false)).thenAnswer(
          (_) async => ExchangeApiKeyModel(
            id: 'fixture',
            key: 'fixture',
            name: 'fixture',
            userId: 'fixture',
            isActive: true,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
        when(
          () => api.getOrderSummary(apiKey: 'fixture', orderId: orderId),
        ).thenThrow(cause);
        when(settings.fetch).thenAnswer(
          (_) async => const SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        );
        final repository = ExchangeOrderRepositoryImpl(
          bullbitcoinApiDatasource: api,
          bullbitcoinApiKeyDatasource: keys,
          isTestnet: false,
        );
        final getOrder = GetOrderUsecase(
          mainnetExchangeOrderRepository: repository,
          testnetExchangeOrderRepository: repository,
          settingsRepository: settings,
        );
        final Object result;
        if (feature == 'pay') {
          result = await GetPayOrderUsecase(
            getOrderUsecase: getOrder,
          ).execute(orderId: orderId);
        } else {
          result = await LoadSellContextUsecase(
            getExchangeUserSummaryUsecase: _Summary(),
            getSettingsUsecase: _GetSettings(),
            getNetworkFeesUsecase: _Fees(),
            getAddressAtIndexUsecase: _Address(),
            getIndexPrice: ({required network, required currency}) =>
                throw StateError('unused'),
            getOrderUsecase: getOrder,
          ).order(orderId: orderId);
        }
        expect(result, isA<Err>());
        expect(
          (result as Err).failure.logMessage,
          '${feature}_order_read_failed category=unexpected',
        );
        verify(
          () => api.getOrderSummary(apiKey: 'fixture', orderId: orderId),
        ).called(1);
        await log.flush();
        final disk = await log.logsFile.readAsString();
        final reports = verify(
          () => reporter.reportError(
            message: captureAny(named: 'message'),
            exception: captureAny(named: 'exception'),
            stackTrace: captureAny(named: 'stackTrace'),
            category: ReportCategory.error,
          ),
        ).captured;
        expect(reports, hasLength(6)); // Two events, all three text arguments.
        expect(reports.whereType<String>(), [
          'exchange_order_read_failed category=unexpected',
          '${feature}_order_read_failed category=unexpected',
        ]);
        expect(reports.whereType<Exception>().map((e) => e.toString()), [
          'Exception: exchange_order_read_failed category=unexpected',
          'Exception: ${feature}_order_read_failed category=unexpected',
        ]);
        expect(reports.whereType<StackTrace>(), hasLength(2));
        final diagnostics = '$disk\n${reports.join('\n')}';
        for (final sentinel in [
          host,
          orderId,
          'DioException',
          'Failed host lookup',
        ]) {
          expect(diagnostics, isNot(contains(sentinel)));
        }
        expect(disk, contains('SEVERE'));
        expect(
          disk,
          contains('exchange_order_read_failed category=unexpected'),
        );
        expect(
          disk,
          contains('${feature}_order_read_failed category=unexpected'),
        );
      },
    );
  }
}
