import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/fund_exchange/data/funding_repository_impl.dart';
import 'package:bb_mobile/features/fund_exchange/data/settings_exchange_environment_adapter.dart';
import 'package:bb_mobile/features/fund_exchange/domain/repositories/funding_repository.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements GetSettingsUsecase {}

class _Repository extends Mock implements FundingRepository {}

void main() {
  test('regtest refuses funding before either repository', () async {
    final settings = _Settings();
    when(() => settings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.regtest,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    final mainnet = _Repository();
    final testnet = _Repository();
    when(() => mainnet.registerResponsibilityConsent())
        .thenAnswer((_) async => const Ok(null));
    final repository = FundingRepositoryImpl(
      bullbitcoinFundingRepository: mainnet,
      bullBitcoinTestnetFundingRepository: testnet,
      exchangeEnvironment: SettingsExchangeEnvironmentAdapter(
        getSettingsUsecase: settings,
      ),
    );

    expect(
      await repository.registerResponsibilityConsent(),
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
