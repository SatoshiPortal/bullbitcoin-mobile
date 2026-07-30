import 'package:bb_mobile/core/ark/usecases/fetch_ark_secret_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/tor/data/usecases/tor_status_usecase.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockElectrumConnectivityPort extends Mock
    implements ElectrumConnectivityPort {}

class _MockBoltzSwapRepository extends Mock implements BoltzSwapRepository {}

class _MockExchangeRateRepository extends Mock
    implements ExchangeRateRepository {}

class _MockPayjoinRepository extends Mock implements PayjoinRepository {}

class _MockFeesRepository extends Mock implements FeesRepository {}

class _MockRecoverBullRepository extends Mock
    implements RecoverBullRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockFetchArkSecretUsecase extends Mock
    implements FetchArkSecretUsecase {}

class _MockTorStatusUsecase extends Mock implements TorStatusUsecase {}

void main() {
  test('disabled Payjoin is not probed or reported offline', () async {
    final payjoinRepository = _MockPayjoinRepository();
    final settingsRepository = _MockSettingsRepository();
    final walletRepository = _MockWalletRepository();
    final torStatusUsecase = _MockTorStatusUsecase();
    when(settingsRepository.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'CAD',
        isPayjoinEnabled: false,
      ),
    );
    when(walletRepository.isTorRequired).thenAnswer((_) async => false);
    when(torStatusUsecase.execute).thenAnswer((_) async => TorStatus.unknown);
    final usecase = CheckAllServiceStatusUsecase(
      electrumConnectivityPort: _MockElectrumConnectivityPort(),
      boltzSwapRepository: _MockBoltzSwapRepository(),
      exchangeRateRepository: _MockExchangeRateRepository(),
      payjoinRepository: payjoinRepository,
      feesRepository: _MockFeesRepository(),
      recoverBullRepository: _MockRecoverBullRepository(),
      walletRepository: walletRepository,
      settingsRepository: settingsRepository,
      fetchArkSecretUsecase: _MockFetchArkSecretUsecase(),
      torStatusUsecase: torStatusUsecase,
    );

    final status = await usecase.execute(network: Network.bitcoinMainnet);

    expect(status.payjoin.status, ServiceStatus.disabled);
    expect(status.payjoin.isOffline, isFalse);
    verifyNever(payjoinRepository.checkOhttpRelayHealth);
  });
}
