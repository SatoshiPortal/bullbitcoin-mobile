import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/status_check/domain/check_service_status_usecase.dart';
import 'package:bb_mobile/features/status_check/domain/status_check_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockCheckAllServiceStatusUsecase extends Mock
    implements CheckAllServiceStatusUsecase {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late _MockGetWalletsUsecase getWalletsUsecase;
  late _MockCheckAllServiceStatusUsecase checkAllServiceStatusUsecase;
  late CheckServiceStatusUsecase usecase;

  setUpAll(() {
    registerFallbackValue(Network.bitcoinMainnet);
  });

  setUp(() {
    getWalletsUsecase = _MockGetWalletsUsecase();
    checkAllServiceStatusUsecase = _MockCheckAllServiceStatusUsecase();
    usecase = CheckServiceStatusUsecase(
      checkAllServiceStatusUsecase: checkAllServiceStatusUsecase,
      getWalletsUsecase: getWalletsUsecase,
    );
  });

  _MockWallet walletWith({required bool isDefault, Network? network}) {
    final wallet = _MockWallet();
    when(() => wallet.isDefault).thenReturn(isDefault);
    if (network != null) {
      when(() => wallet.network).thenReturn(network);
    }
    return wallet;
  }

  group('CheckServiceStatusUsecase', () {
    test(
      'returns NoDefaultWalletFailure when no wallet is the default',
      () async {
        when(
          () => getWalletsUsecase.execute(),
        ).thenAnswer((_) async => [walletWith(isDefault: false)]);

        final result = await usecase.execute();

        expect(result, isA<Err<AllServicesStatus, StatusCheckFailure>>());
        final failure =
            (result as Err<AllServicesStatus, StatusCheckFailure>).failure;
        expect(failure, isA<NoDefaultWalletFailure>());
      },
    );

    test('maps a NoWalletsFoundException to NoDefaultWalletFailure without '
        'leaking the raw reason (NoDefaultWalletFailure carries no message '
        'field, so it structurally cannot leak)', () async {
      when(() => getWalletsUsecase.execute()).thenThrow(
        NoWalletsFoundException(
          'No wallets found for the current environment: mainnet',
        ),
      );

      final result = await usecase.execute();

      expect(result, isA<Err<AllServicesStatus, StatusCheckFailure>>());
      expect(
        (result as Err<AllServicesStatus, StatusCheckFailure>).failure,
        isA<NoDefaultWalletFailure>(),
      );
    });

    test('maps an unexpected GetWalletsUsecase failure to a sanitized failure '
        'without leaking the raw reason', () async {
      when(
        () => getWalletsUsecase.execute(),
      ).thenThrow(Exception('electrum: connection reset by 1.2.3.4'));

      final result = await usecase.execute();

      expect(result, isA<Err<AllServicesStatus, StatusCheckFailure>>());
      final failure =
          (result as Err<AllServicesStatus, StatusCheckFailure>).failure;
      expect(failure, isA<StatusCheckUnexpectedFailure>());
      // The raw reason lives only in the log-only `logMessage` field, and
      // `toTranslated` never reads it — asserted by the l10n extension's
      // exhaustive switch, not here.
    });

    test('maps an unexpected CheckAllServiceStatusUsecase failure to a '
        'sanitized failure', () async {
      when(() => getWalletsUsecase.execute()).thenAnswer(
        (_) async => [
          walletWith(isDefault: true, network: Network.bitcoinMainnet),
        ],
      );
      when(
        () => checkAllServiceStatusUsecase.execute(
          network: any(named: 'network'),
        ),
      ).thenThrow(Exception('unexpected internal failure'));

      final result = await usecase.execute();

      expect(
        (result as Err<AllServicesStatus, StatusCheckFailure>).failure,
        isA<StatusCheckUnexpectedFailure>(),
      );
    });

    test('returns Ok with the service status on success', () async {
      when(() => getWalletsUsecase.execute()).thenAnswer(
        (_) async => [
          walletWith(isDefault: true, network: Network.bitcoinMainnet),
        ],
      );
      const status = AllServicesStatus();
      when(
        () => checkAllServiceStatusUsecase.execute(
          network: any(named: 'network'),
        ),
      ).thenAnswer((_) async => status);

      final result = await usecase.execute();

      expect(result, isA<Ok<AllServicesStatus, StatusCheckFailure>>());
      expect(
        (result as Ok<AllServicesStatus, StatusCheckFailure>).value,
        status,
      );
    });
  });
}
