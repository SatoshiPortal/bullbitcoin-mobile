import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

abstract interface class BitcoinPriceRepository {
  Future<List<String>> get availableCurrencies;

  /// When the price served for [currency] was fetched from the pricer, or null
  /// when none is held. A read may be answered from a recent fetch without a
  /// request, so this is when the pricer last answered for it.
  DateTime? priceFetchedAt(String currency);

  @useResult
  Future<Result<double, PricerFailure>> getCurrencyValue({
    required BigInt amountSat,
    required String currency,
  });

  @useResult
  Future<Result<BigInt, PricerFailure>> getSatsValue({
    required double amountFiat,
    required String currency,
  });

  /// Convert an amount from one fiat currency to another using BTC as intermediary.
  /// Returns the converted amount in the target currency.
  @useResult
  Future<Result<double, PricerFailure>> convertFiatToFiat({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  });
}
