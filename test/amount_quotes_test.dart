import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_amount_quotes_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_amount_quotes_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_amount_quotes_usecase.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements Preferences {}

void main() {
  final at = DateTime.utc(2026, 11, 19, 14, 32);
  for (final environment in Environment.values) {
    test(
      'amount quote boundaries capture $environment and preserve the quote time',
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
        Future<Result<Map<SupportedCurrency, BitcoinPrice>, PricerFailure>>
        read({required BitcoinNetwork network}) async {
          networks.add(network);
          return Ok({
            SupportedCurrency.cad: BitcoinPrice(
              currency: SupportedCurrency.cad,
              fiatAmount: 125000,
              fetchedAt: at,
            ),
          });
        }

        final boundaries = [
          GetSendAmountQuotesUsecase(settings: settings, read: read).execute,
          GetReceiveAmountQuotesUsecase(settings: settings, read: read).execute,
          GetSwapAmountQuotesUsecase(settings: settings, read: read).execute,
        ];
        for (final execute in boundaries) {
          switch (await execute()) {
            case Ok(:final value):
              expect(value[SupportedCurrency.cad]?.fetchedAt, at);
            case Err(:final failure):
              fail('Expected the available quote: $failure');
          }
        }
        expect(
          networks,
          List.filled(3, switch (environment) {
            Environment.mainnet => BitcoinNetwork.mainnet,
            Environment.testnet => BitcoinNetwork.testnet,
            Environment.regtest => BitcoinNetwork.regtest,
          }),
        );
      },
    );
  }
}
