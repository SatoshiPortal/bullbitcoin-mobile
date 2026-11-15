import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/watch_wallet_revisions_usecase.dart';
import 'package:bb_mobile/features/wallet/data/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/check_wallet_is_liquid_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_list_usecase.dart';
import 'package:bb_mobile/features/address_view/presentation/address_view_bloc.dart';
import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/features/address_view/data/address_electrum_datasource.dart';
import 'package:bb_mobile/features/address_view/data/address_explorer_repository_impl.dart';
import 'package:bb_mobile/features/address_view/domain/repositories/address_explorer_repository.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/find_address_owner_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_overview_usecase.dart';
import 'package:bb_mobile/features/address_view/presentation/address_explorer_cubit.dart';
import 'package:bb_mobile/features/address_view/public/address_explorer_route.dart';
import 'package:bb_mobile/features/wallet/data/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/add_address_label_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_labels_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart' show LabelsFacade;
import 'package:get_it/get_it.dart';

class AddressViewLocator {
  static void setup(GetIt locator) {
    registerRepositories(locator);
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<AddressExplorerRepository>(
      () => AddressExplorerRepositoryImpl(
        datasource: AddressElectrumDatasource(
          servers: locator<ElectrumServersPort>(),
          socketConnector: locator<ElectrumSocketConnector>(),
        ),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetAddressOverviewUsecase>(
      () => GetAddressOverviewUsecase(
        repository: locator<AddressExplorerRepository>(),
      ),
    );
    locator.registerFactory<FindAddressOwnerUsecase>(
      () => FindAddressOwnerUsecase(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        bitcoinSendPort: locator<BitcoinWalletRepository>(),
      ),
    );
    locator.registerFactory<GetAddressListUsecase>(
      () => GetAddressListUsecase(
        walletAddressRepository: locator<WalletAddressRepository>(),
      ),
    );
    locator.registerFactory<CheckWalletIsLiquidUsecase>(
      () => CheckWalletIsLiquidUsecase(
        getWalletUsecase: locator<GetWalletUsecase>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    // Register the AddressViewBloc with the locator
    locator.registerFactoryParam<AddressViewBloc, String, int?>(
      (walletId, limit) => AddressViewBloc(
        watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(
          locator<WalletFacade>(),
        ),
        checkWalletIsLiquidUsecase: locator<CheckWalletIsLiquidUsecase>(),
        getAddressListUsecase: locator<GetAddressListUsecase>(),
        walletId: walletId,
        limit: limit,
      ),
    );
    locator
        .registerFactoryParam<AddressExplorerCubit, AddressExplorerArgs, void>(
          (args, _) => AddressExplorerCubit(
            address: args.address,
            network: args.network,
            getAddressOverviewUsecase: locator<GetAddressOverviewUsecase>(),
            findAddressOwnerUsecase: locator<FindAddressOwnerUsecase>(),
            getAddressLabelsUsecase: GetAddressLabelsUsecase(
              labelsFacade: locator<LabelsFacade>(),
            ),
            addAddressLabelUsecase: AddAddressLabelUsecase(
              labelsFacade: locator<LabelsFacade>(),
            ),
          ),
        );
  }
}
