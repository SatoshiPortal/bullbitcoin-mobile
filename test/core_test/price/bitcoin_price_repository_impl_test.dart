import 'package:bb_mobile/core/price/data/bitcoin_price_repository_impl.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

/// Stands in for the pricer's index price, and records what was asked.
final class _FakeIndexPrice {
  Result<BitcoinPrice, PricerFailure> Function(SupportedCurrency currency)
  answer = (currency) => Ok(
    BitcoinPrice(
      currency: currency,
      fiatAmount: 70000,
      fetchedAt: DateTime.utc(2026, 10, 28, 12),
    ),
  );
  final asked = <(BitcoinNetwork, SupportedCurrency)>[];

  Future<Result<BitcoinPrice, PricerFailure>> call({
    required BitcoinNetwork network,
    required SupportedCurrency currency,
  }) async {
    asked.add((network, currency));
    return answer(currency);
  }
}

void main() {
  final oneBtc = BigInt.from(100000000);

  late _FakeIndexPrice pricer;
  late BitcoinPriceRepositoryImpl repository;

  setUp(() {
    pricer = _FakeIndexPrice();
    repository = BitcoinPriceRepositoryImpl(
      network: BitcoinNetwork.mainnet,
      indexPrice: pricer.call,
    );
  });

  test('converts with the index price', () async {
    expect(
      await repository.getCurrencyValue(amountSat: oneBtc, currency: 'USD'),
      70000,
    );
    expect(
      await repository.getSatsValue(amountFiat: 700, currency: 'usd'),
      BigInt.from(1000000),
    );
  });

  test('asks the pricer on its own network', () async {
    final testnet = BitcoinPriceRepositoryImpl(
      network: BitcoinNetwork.testnet,
      indexPrice: pricer.call,
    );

    await testnet.getCurrencyValue(amountSat: oneBtc, currency: 'CAD');

    expect(pricer.asked.single, (
      BitcoinNetwork.testnet,
      SupportedCurrency.cad,
    ));
  });

  test('a failed read gives no price', () async {
    pricer.answer = (_) => const Err(PricerNetworkFailure('Timed out'));

    expect(
      await repository.getCurrencyValue(amountSat: oneBtc, currency: 'USD'),
      0,
    );
  });

  test('a currency the pricer does not support gives no price', () async {
    expect(
      await repository.getCurrencyValue(amountSat: oneBtc, currency: 'JPY'),
      0,
    );
    expect(pricer.asked, isEmpty);
  });

  test('tells when the price it serves was fetched', () async {
    expect(repository.priceFetchedAt('USD'), isNull);

    await repository.getCurrencyValue(amountSat: oneBtc, currency: 'USD');

    expect(repository.priceFetchedAt('usd'), DateTime.utc(2026, 10, 28, 12));
    expect(repository.priceFetchedAt('CAD'), isNull);
  });

  test('forgets when a price was fetched once a read fails', () async {
    await repository.getCurrencyValue(amountSat: oneBtc, currency: 'USD');
    pricer.answer = (_) => const Err(PricerNetworkFailure('Timed out'));

    await repository.getCurrencyValue(amountSat: oneBtc, currency: 'USD');

    expect(repository.priceFetchedAt('USD'), isNull);
  });

  test('offers the currencies the pricer supports', () async {
    expect(await repository.availableCurrencies, [
      for (final currency in SupportedCurrency.values) currency.code,
    ]);
  });
}
