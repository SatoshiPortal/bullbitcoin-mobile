import 'package:bb_mobile/core/labels/domain/get_address_labels_usecase.dart';
import 'package:bb_mobile/core/labels/domain/get_output_labels_usecase.dart';
import 'package:bb_mobile/core/labels/domain/get_transaction_labels_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/utxos/application/usecases/get_utxo_usecase.dart';
import 'package:bb_mobile/features/utxos/application/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/utxos/domain/ports/labels_port.dart';
import 'package:bb_mobile/features/utxos/domain/ports/utxos_port.dart';
import 'package:bb_mobile/features/utxos/domain/ports/wallet_port.dart';
import 'package:bb_mobile/features/utxos/infrastructure/adapters/bdk_utxos_adapter.dart';
import 'package:bb_mobile/features/utxos/infrastructure/adapters/lwk_utxos_adapter.dart';
import 'package:bb_mobile/features/utxos/infrastructure/adapters/utxos_adapter_coordinator.dart';
import 'package:bb_mobile/features/utxos/infrastructure/factories/bdk_wallet_factory.dart';
import 'package:bb_mobile/features/utxos/infrastructure/factories/lwk_wallet_factory.dart';
import 'package:bb_mobile/features/utxos/interface_adapters/facades/labels_facade.dart';
import 'package:bb_mobile/features/utxos/interface_adapters/facades/wallet_facade.dart';
import 'package:bb_mobile/features/utxos/interface_adapters/presenters/bloc/utxos_bloc.dart';
import 'package:bb_mobile/locator.dart';

class UtxosLocator {
  static void registerFactories() {
    locator.registerLazySingleton<BdkWalletFactory>(
      () => const BdkWalletFactory(),
    );

    locator.registerLazySingleton<LwkWalletFactory>(
      () => const LwkWalletFactory(),
    );
  }

  static void registerAdapters() {
    locator.registerLazySingleton<BdkUtxosAdapter>(
      () => BdkUtxosAdapter(bdkWalletFactory: locator<BdkWalletFactory>()),
    );

    locator.registerLazySingleton<LwkUtxosAdapter>(
      () => LwkUtxosAdapter(lwkWalletFactory: locator<LwkWalletFactory>()),
    );

    // Register the coordinator that implements UtxosPort
    locator.registerLazySingleton<UtxosPort>(
      () => UtxosAdapterCoordinator(
        bdkUtxosAdapter: locator<BdkUtxosAdapter>(),
        lwkUtxosAdapter: locator<LwkUtxosAdapter>(),
      ),
    );
  }

  static void registerUseCases() {
    locator.registerFactory<GetUtxoUsecase>(
      () => GetUtxoUsecase(
        labelsPort: locator(),
        walletPort: locator(),
        utxosPort: locator<UtxosPort>(),
      ),
    );

    locator.registerFactory<GetWalletUtxosUsecase>(
      () => GetWalletUtxosUsecase(
        labelsPort: locator(),
        walletPort: locator(),
        utxosPort: locator<UtxosPort>(),
      ),
    );
  }

  static void registerBlocs() {
    locator.registerFactory(
      () => UtxosBloc(
        getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
        getUtxoUsecase: locator<GetUtxoUsecase>(),
      ),
    );
  }

  static void registerFacades() {
    locator.registerLazySingleton<WalletPort>(
      () => WalletFacade(getWalletUsecase: locator<GetWalletUsecase>()),
    );
    locator.registerLazySingleton<LabelsPort>(
      () => LabelsFacade(
        getAddressLabelsUsecase: locator<GetAddressLabelsUsecase>(),
        getTransactionLabelsUsecase: locator<GetTransactionLabelsUsecase>(),
        getOutputLabelsUsecase: locator<GetOutputLabelsUsecase>(),
      ),
    );
  }

  static void setup() {
    registerFactories();
    registerAdapters();
    registerUseCases();
    registerBlocs();
    registerFacades();
  }
}
