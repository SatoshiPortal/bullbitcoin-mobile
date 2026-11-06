import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/delegating_funding_gateway.dart';
import 'package:bb_mobile/features/fund_exchange/adapters/settings_exchange_environment_adapter.dart';
import 'package:bb_mobile/features/fund_exchange/application/ports/funding_gateway_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements GetSettingsUsecase {}

class _Gateway extends Mock implements FundingGatewayPort {}

void main() {
  test('regtest refuses funding before either gateway', () async {
    final settings = _Settings();
    when(() => settings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.regtest,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    final mainnet = _Gateway();
    final testnet = _Gateway();
    when(
      () => mainnet.registerResponsibilityConsent(),
    ).thenAnswer((_) async => const Ok(null));
    final gateway = DelegatingFundingGateway(
      bullbitcoinFundingGateway: mainnet,
      bullBitcoinTestnetFundingGateway: testnet,
      exchangeEnvironment: SettingsExchangeEnvironmentAdapter(
        getSettingsUsecase: settings,
      ),
    );

    expect(
      await gateway.registerResponsibilityConsent(),
      isA<Err<void, FundExchangeFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<FundExchangeUnsupportedNetworkFailure>(),
      ),
    );
    verifyZeroInteractions(mainnet);
    verifyZeroInteractions(testnet);
  });
}
