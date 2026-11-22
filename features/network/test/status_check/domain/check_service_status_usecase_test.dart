import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network/src/status_check/domain/check_all_service_status_usecase.dart';
import 'package:network/src/status_check/domain/check_service_status_usecase.dart';
import 'package:network/src/status_check/domain/service_status.dart';
import 'package:network/src/status_check/domain/network_failure.dart';
import 'package:primitives/primitives.dart';

class _MockCheckAllServiceStatusUsecase extends Mock
    implements CheckAllServiceStatusUsecase {}

class _WalletReadFailure extends Failure {
  const _WalletReadFailure() : super('wallet storage could not be read');
}

void main() {
  late Future<Result<NetworkEnv?, Failure>> Function() readNetwork;
  late _MockCheckAllServiceStatusUsecase checkAll;
  late CheckServiceStatusUsecase usecase;

  setUp(() {
    checkAll = _MockCheckAllServiceStatusUsecase();
    readNetwork = () async => const Ok(NetworkEnv.mainnet);
    usecase = CheckServiceStatusUsecase(
      checkAllServiceStatusUsecase: checkAll,
      readDefaultNetwork: () => readNetwork(),
    );
  });

  test('reports no default wallet when the network is absent', () async {
    readNetwork = () async => const Ok(null);

    expect(
      await usecase.execute(),
      isA<Err<AllServicesStatus, NetworkFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<NoDefaultWalletFailure>(),
      ),
    );
    verifyZeroInteractions(checkAll);
  });

  test('classifies a wallet storage failure as unexpected', () async {
    readNetwork = () async => const Err(_WalletReadFailure());

    expect(
      await usecase.execute(),
      isA<Err<AllServicesStatus, NetworkFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<NetworkUnexpectedFailure>(),
      ),
    );
    verifyZeroInteractions(checkAll);
  });

  test(
    'classifies an exception reading the default network as unexpected',
    () async {
      readNetwork = () async => throw Exception('connection reset');
      final result = await usecase.execute();
      expect(
        (result as Err<AllServicesStatus, NetworkFailure>).failure,
        isA<NetworkUnexpectedFailure>(),
      );
    },
  );

  test(
    'keeps a service exception distinct from an absent default wallet',
    () async {
      when(() => checkAll.execute(network: NetworkEnv.mainnet))
          .thenThrow(Exception('unexpected: no wallets found'));

      final result = await usecase.execute();
      expect(
        (result as Err<AllServicesStatus, NetworkFailure>).failure,
        isA<NetworkUnexpectedFailure>(),
      );
    },
  );

  test('returns the status for the captured default network', () async {
    readNetwork = () async => const Ok(NetworkEnv.regtest);
    const status = AllServicesStatus();
    when(() => checkAll.execute(network: NetworkEnv.regtest))
        .thenAnswer((_) async => status);

    expect(
      await usecase.execute(),
      isA<Ok<AllServicesStatus, NetworkFailure>>().having(
        (result) => result.value,
        'status',
        status,
      ),
    );
  });
}
