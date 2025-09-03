import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/dca/domain/usecases/set_dca_usecase.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/locator.dart';

class DcaLocator {
  static void setup() {
    registerUsecases();
    registerBlocs();
  }

  static void registerUsecases() {
    locator.registerFactory<SetDcaUsecase>(
      () => SetDcaUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        wallet: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        walletAddressRepository: locator<WalletAddressRepository>(),
      ),
    );
  }

  static void registerBlocs() {
    locator.registerFactory<DcaBloc>(
      () => DcaBloc(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        setDcaUsecase: locator<SetDcaUsecase>(),
      ),
    );
  }
}
