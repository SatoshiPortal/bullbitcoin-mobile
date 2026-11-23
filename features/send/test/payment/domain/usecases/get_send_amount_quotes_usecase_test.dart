import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:send/src/payment/domain/usecases/get_send_amount_quotes_usecase.dart';

class _Settings extends Mock implements Preferences {}

void main() {
  final at = DateTime.utc(2026, 11, 19, 14, 32);
  for (final environment in Environment.values) {
    test(
      'Send fetches quotes for $environment and preserves the quote time',
      () async {
        final settings = _Settings();
        when(settings.fetch).thenAnswer(
          (_) async => Ok(
            SettingsEntity(
              environment: environment,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
            ),
          ),
        );
        final networks = <BitcoinNetwork>[];
        final usecase = GetSendAmountQuotesUsecase(
          settings: settings,
          read: ({required network}) async {
            networks.add(network);
            return Ok({
              SupportedCurrency.cad: BitcoinPrice(
                currency: SupportedCurrency.cad,
                fiatAmount: 125000,
                fetchedAt: at,
              ),
            });
          },
        );
        switch (await usecase.execute()) {
          case Ok(:final value):
            expect(value[SupportedCurrency.cad]?.fetchedAt, at);
          case Err(:final failure):
            fail('Expected the available quote: $failure');
        }
        expect(networks, [
          switch (environment) {
            Environment.mainnet => BitcoinNetwork.mainnet,
            Environment.testnet => BitcoinNetwork.testnet,
            Environment.regtest => BitcoinNetwork.regtest,
          },
        ]);
      },
    );
  }
}
