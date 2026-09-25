import 'package:bb_mobile/core/exchange/domain/entity/historical_rate_series.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction_anchor.dart';

/// What a transaction was worth when it happened, ready to render.
///
/// Null means there is nothing to show, which is a real answer rather than a
/// failure: the rate history starts on 2023-03-15 and has gaps of up to 17
/// consecutive days, and some transactions have no anchor at all.
sealed class HistoricalValue {
  const HistoricalValue();

  /// Prices [anchor] against [series].
  ///
  /// A range whose ends cannot both be priced degrades to a single value at
  /// its later end, which is the confirming block — the end that is always
  /// verifiable. A range that resolves to the same figure at both ends also
  /// degrades, since a range showing one number twice reads as a bug.
  static HistoricalValue? resolve({
    required TransactionAnchor anchor,
    required HistoricalRateSeries series,
    required int amountSat,
  }) {
    double? fiatAt(DateTime moment) {
      final rate = series.priceAt(moment);
      if (rate == null) return null;
      return ConvertAmount.satsToFiat(amountSat, rate);
    }

    switch (anchor) {
      case NoAnchor():
        return null;

      case SingleAnchor(:final at, :final reason):
        final fiat = fiatAt(at);
        if (fiat == null) return null;
        return SingleValue(fiat: fiat, at: at, reason: reason);

      case RangeAnchor(:final from, :final to):
        final endFiat = fiatAt(to);
        final startFiat = fiatAt(from);
        if (endFiat == null) return null;
        if (startFiat == null || startFiat == endFiat) {
          return SingleValue(
            fiat: endFiat,
            at: to,
            reason: AnchorReason.confirmed,
          );
        }
        return RangeValue(
          low: startFiat < endFiat ? startFiat : endFiat,
          high: startFiat < endFiat ? endFiat : startFiat,
          from: from,
          to: to,
        );
    }
  }
}

/// One figure, priced at one moment.
class SingleValue extends HistoricalValue {
  final double fiat;
  final DateTime at;
  final AnchorReason reason;
  const SingleValue({
    required this.fiat,
    required this.at,
    required this.reason,
  });
}

/// A window the value sat somewhere inside, because the send moment of an
/// incoming on-chain payment is not knowable.
class RangeValue extends HistoricalValue {
  final double low;
  final double high;
  final DateTime from;
  final DateTime to;
  const RangeValue({
    required this.low,
    required this.high,
    required this.from,
    required this.to,
  });
}
