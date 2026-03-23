import 'package:bb_mobile/core/dlc/data/datasources/dlc_api_datasource.dart';
import 'package:bb_mobile/core/dlc/data/datasources/dlc_wallet_token_store.dart';
import 'package:bb_mobile/core/dlc/data/repositories/dlc_repository_impl.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/accept_offer_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/cancel_dlc_order_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/check_dlc_connection_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_contract_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_contracts_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_instruments_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_my_orders_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_orderbook_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/place_dlc_order_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/register_dlc_wallet_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/sign_and_submit_cets_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/sign_dlc_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/take_order_usecase.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/auth/dlc_wallet_auth_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/connection/dlc_connection_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/contracts/dlc_contracts_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/instruments/dlc_instruments_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/my_orders/dlc_my_orders_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/orderbook/dlc_orderbook_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/place_order/dlc_place_order_cubit.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

/// Base URL of the DLC coordinator REST API.
/// TODO: move to settings / environment config.
const _dlcCoordinatorBaseUrl = 'https://dlc-coordinator.bullbitcoin.com/api/v1';

class DlcLocator {
  static void setup(GetIt locator) {
    _registerDatasources(locator);
    _registerRepositories(locator);
    _registerUsecases(locator);
    _registerBlocs(locator);
  }

  static void _registerDatasources(GetIt locator) {
    locator.registerLazySingleton<DlcWalletTokenStore>(
      () => DlcWalletTokenStore(),
    );
    locator.registerLazySingleton<DlcApiDatasource>(
      () => DlcApiDatasource(
        dio: locator<Dio>(),
        baseUrl: _dlcCoordinatorBaseUrl,
        tokenStore: locator<DlcWalletTokenStore>(),
      ),
    );
  }

  static void _registerRepositories(GetIt locator) {
    locator.registerLazySingleton<DlcRepository>(
      () => DlcRepositoryImpl(
        datasource: locator<DlcApiDatasource>(),
      ),
    );
  }

  static void _registerUsecases(GetIt locator) {
    locator.registerFactory<RegisterDlcWalletUsecase>(
      () => RegisterDlcWalletUsecase(
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
        utxoRepository: locator<WalletUtxoRepository>(),
        dlcApiDatasource: locator<DlcApiDatasource>(),
        tokenStore: locator<DlcWalletTokenStore>(),
      ),
    );
    locator.registerFactory<CheckDlcConnectionUsecase>(
      () => CheckDlcConnectionUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<GetInstrumentsUsecase>(
      () => GetInstrumentsUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<GetOrderbookUsecase>(
      () => GetOrderbookUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<GetMyOrdersUsecase>(
      () => GetMyOrdersUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<PlaceDlcOrderUsecase>(
      () => PlaceDlcOrderUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<CancelDlcOrderUsecase>(
      () => CancelDlcOrderUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<AcceptOfferUsecase>(
      () => AcceptOfferUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<TakeOrderUsecase>(
      () => TakeOrderUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<SignDlcUsecase>(
      () => SignDlcUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<GetContractsUsecase>(
      () => GetContractsUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<GetContractUsecase>(
      () => GetContractUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<SignAndSubmitCetsUsecase>(
      () => SignAndSubmitCetsUsecase(
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
        dlcRepository: locator<DlcRepository>(),
      ),
    );
  }

  static void _registerBlocs(GetIt locator) {
    locator.registerFactory<DlcWalletAuthCubit>(
      () => DlcWalletAuthCubit(
        registerDlcWalletUsecase: locator<RegisterDlcWalletUsecase>(),
        tokenStore: locator<DlcWalletTokenStore>(),
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );
    locator.registerFactory<DlcConnectionCubit>(
      () => DlcConnectionCubit(
        checkDlcConnectionUsecase: locator<CheckDlcConnectionUsecase>(),
      ),
    );
    // DlcInstrumentsCubit is a lazy singleton so all tabs share the same
    // instruments list and selected instrument.
    locator.registerLazySingleton<DlcInstrumentsCubit>(
      () => DlcInstrumentsCubit(
        getInstrumentsUsecase: locator<GetInstrumentsUsecase>(),
      ),
    );
    locator.registerFactory<DlcOrderbookCubit>(
      () => DlcOrderbookCubit(
        getOrderbookUsecase: locator<GetOrderbookUsecase>(),
      ),
    );
    locator.registerFactory<DlcMyOrdersCubit>(
      () => DlcMyOrdersCubit(
        getMyOrdersUsecase: locator<GetMyOrdersUsecase>(),
        cancelDlcOrderUsecase: locator<CancelDlcOrderUsecase>(),
        signAndSubmitCetsUsecase: locator<SignAndSubmitCetsUsecase>(),
      ),
    );
    locator.registerFactory<DlcPlaceOrderCubit>(
      () => DlcPlaceOrderCubit(
        placeDlcOrderUsecase: locator<PlaceDlcOrderUsecase>(),
        tokenStore: locator<DlcWalletTokenStore>(),
      ),
    );
    // DlcContractsCubit is a lazy singleton so the contracts list and detail
    // screens share the same instance (preserving selectedContract state).
    locator.registerLazySingleton<DlcContractsCubit>(
      () => DlcContractsCubit(
        getContractsUsecase: locator<GetContractsUsecase>(),
        getContractUsecase: locator<GetContractUsecase>(),
        signAndSubmitCetsUsecase: locator<SignAndSubmitCetsUsecase>(),
      ),
    );
  }
}
