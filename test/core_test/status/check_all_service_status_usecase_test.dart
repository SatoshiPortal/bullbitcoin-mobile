import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/tor_status_usecase.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Ok;

class _MockElectrumConnectivityPort extends Mock
    implements ElectrumConnectivityPort {}

class _MockExchangeRateRepository extends Mock
    implements ExchangeRateRepository {}

class _MockPayjoinPolicyAccess extends Mock implements PayjoinPolicyAccess {}

class _MockPayjoinDiagnostics extends Mock implements PayjoinDiagnostics {}

class _MockFeesRepository extends Mock implements FeesRepository {}

class _MockRecoverBullRepository extends Mock
    implements RecoverBullRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockTorStatusUsecase extends Mock implements TorStatusUsecase {}

void main() {
  test('disabled Payjoin is not probed or reported offline', () async {
    final payjoinPolicy = _MockPayjoinPolicyAccess();
    final payjoinDiagnostics = _MockPayjoinDiagnostics();
    final walletRepository = _MockWalletRepository();
    final torStatusUsecase = _MockTorStatusUsecase();
    when(walletRepository.isTorRequired).thenAnswer((_) async => false);
    when(torStatusUsecase.execute).thenAnswer((_) async => TorStatus.unknown);
    when(
      payjoinPolicy.load,
    ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
    final usecase = CheckAllServiceStatusUsecase(
      electrumConnectivityPort: _MockElectrumConnectivityPort(),
      exchangeRateRepository: _MockExchangeRateRepository(),
      payjoinPolicy: payjoinPolicy,
      payjoinDiagnostics: payjoinDiagnostics,
      feesRepository: _MockFeesRepository(),
      recoverBullRepository: _MockRecoverBullRepository(),
      walletRepository: walletRepository,
      torStatusUsecase: torStatusUsecase,
    );

    final status = await usecase.execute(network: Network.bitcoinMainnet);

    expect(status.payjoin.status, ServiceStatus.disabled);
    expect(status.payjoin.isOffline, isFalse);
    verifyNever(payjoinDiagnostics.relayHealth);
  });
}
