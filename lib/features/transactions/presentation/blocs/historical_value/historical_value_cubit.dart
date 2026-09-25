import 'package:bb_mobile/core/exchange/domain/entity/historical_rate_series.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/transactions/data/datasources/send_timestamp_datasource.dart';
import 'package:bb_mobile/features/transactions/application/usecases/load_historical_rates_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction_anchor.dart';
import 'package:bb_mobile/features/transactions/presentation/historical_value.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Holds everything needed to price a transaction at the moment it happened.
///
/// This sits above the transaction surfaces rather than inside either existing
/// cubit, so a row can resolve its value without a database round trip on the
/// scroll path: the whole rate series is about 9,863 entries, near 1 MB, and
/// is searched in memory.
class HistoricalValueCubit extends Cubit<HistoricalValueState> {
  HistoricalValueCubit({
    required LoadHistoricalRatesUsecase loadHistoricalRatesUsecase,
    required SendTimestampDatasource sendTimestampDatasource,
    required GetSettingsUsecase getSettingsUsecase,
  }) : _loadHistoricalRates = loadHistoricalRatesUsecase,
       _sendTimestamps = sendTimestampDatasource,
       _getSettings = getSettingsUsecase,
       super(const HistoricalValueState());

  final LoadHistoricalRatesUsecase _loadHistoricalRates;
  final SendTimestampDatasource _sendTimestamps;
  final GetSettingsUsecase _getSettings;

  /// Shows whatever is cached at once, then refreshes in the background.
  ///
  /// Nothing blocks on the network. A row with no rate yet shows nothing and
  /// fills in when the refresh lands, which is the same as every other
  /// unknown-rate case.
  Future<void> load() async {
    try {
      final settings = await _getSettings.execute();
      final currency = settings.currencyCode;

      final sentAt = await _sendTimestamps.fetchAll();
      final cached = await _loadHistoricalRates.cached(currency);
      emit(
        HistoricalValueState(
          currencyCode: currency,
          series: cached,
          sentAt: sentAt,
        ),
      );

      final refreshed = await _loadHistoricalRates.refresh(currency);
      if (isClosed) return;
      emit(
        HistoricalValueState(
          currencyCode: currency,
          series: refreshed,
          sentAt: sentAt,
        ),
      );
    } catch (e) {
      log.warning('Failed to load historical values', error: e);
    }
  }
}

class HistoricalValueState {
  const HistoricalValueState({
    this.currencyCode,
    this.series,
    this.sentAt = const {},
  });

  final String? currencyCode;
  final HistoricalRateSeries? series;

  /// Recorded broadcast moments, by txid. Local, and empty after a restore.
  final Map<String, DateTime> sentAt;

  /// What [transaction] was worth when it happened, or null to show nothing.
  HistoricalValue? valueFor(Transaction transaction) {
    final series = this.series;
    if (series == null || series.isEmpty) return null;

    final txId = transaction.txId;
    final anchor = TransactionAnchor.of(
      transaction,
      sentAt: txId == null ? null : sentAt[txId],
    );

    return HistoricalValue.resolve(
      anchor: anchor,
      series: series,
      amountSat: transaction.swapDisplayAmountSat,
    );
  }
}
