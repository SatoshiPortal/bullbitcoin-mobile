import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/deep_link.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/launcher.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/mnemonic_word.dart';
import 'package:bb_mobile/_pkg/nfc.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/balance.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/address.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/balance.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/create.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/network.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sync.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/utxo.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/address.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/balance.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/create.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sync.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/network.dart';
import 'package:bb_mobile/_pkg/wallet/repository/network.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/import/bloc/words_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

const bbVersion = '0.2.0-4';

GetIt locator = GetIt.instance;

Future setupLocator({bool fromTest = false}) async {
  if (fromTest) return;

  locator.registerSingleton<Logger>(Logger());

  await _setupStorage();
  await _setupAPIs();
  await _setupRepositories();
  await _setupAppServices();
  await _setupWalletServices();
  await _setupBlocs();
}

Future _setupStorage() async {
  final (secureStorage, hiveStorage) = await setupStorage();
  locator.registerSingleton<SecureStorage>(secureStorage);
  locator.registerSingleton<HiveStorage>(hiveStorage);
}

Future _setupAPIs() async {
  locator.registerSingleton<Dio>(Dio());
  locator.registerSingleton<BullBitcoinAPI>(BullBitcoinAPI(locator<Dio>()));
  locator.registerSingleton<MempoolAPI>(MempoolAPI(locator<Dio>()));
}

Future _setupRepositories() async {
  locator.registerSingleton<WalletsRepository>(WalletsRepository());
  locator.registerSingleton<NetworkRepository>(NetworkRepository());
  locator.registerSingleton<WalletsStorageRepository>(
    WalletsStorageRepository(hiveStorage: locator<HiveStorage>()),
  );
  locator.registerSingleton<WalletSensitiveStorageRepository>(
    WalletSensitiveStorageRepository(
      secureStorage: locator<SecureStorage>(),
    ),
  );
  // locator.registerSingleton<HomeRepository>(
  //   HomeRepository(
  //     walletsStorageRepository: locator<WalletsStorageRepository>(),
  //     logger: locator<Logger>(),
  //   ),
  // );
}

Future _setupAppServices() async {
  locator.registerSingleton<NavName>(NavName());
  locator.registerSingleton<GoRouter>(setupRouter());
  final deepLink = DeepLink();
  locator.registerSingleton<DeepLink>(deepLink);
  locator.registerSingleton<Lighting>(
    Lighting(
      hiveStorage: locator<HiveStorage>(),
    ),
  );

  locator.registerSingleton<Barcode>(Barcode());
  locator.registerSingleton<Launcher>(Launcher());
  locator.registerSingleton<NFCPicker>(NFCPicker());
  locator.registerSingleton<FilePick>(FilePick());
  locator.registerSingleton<Clippboard>(Clippboard());
  locator.registerSingleton<WordsCubit>(
    WordsCubit(
      mnemonicWords: MnemonicWords(),
    ),
  );

  locator.registerSingleton<FileStorage>(FileStorage());
}

Future _setupWalletServices() async {
  locator.registerSingleton<SwapBoltz>(
    SwapBoltz(
      secureStorage: locator<SecureStorage>(),
    ),
  );

  locator.registerFactory<BDKSync>(() => BDKSync());
  locator.registerFactory<LWKSync>(() => LWKSync());
  locator.registerSingleton<BDKBalance>(BDKBalance());
  locator.registerSingleton<LWKBalance>(LWKBalance());
  locator.registerSingleton<BDKNetwork>(BDKNetwork());
  locator.registerSingleton<BDKAddress>(BDKAddress());
  locator.registerSingleton<LWKAddress>(LWKAddress());
  locator.registerSingleton<BDKTransactions>(BDKTransactions());
  locator.registerSingleton<LWKTransactions>(
    LWKTransactions(
      networkRepository: locator<NetworkRepository>(),
      swapBoltz: locator<SwapBoltz>(),
    ),
  );
  locator.registerSingleton<BDKUtxo>(BDKUtxo());
  locator.registerSingleton<LWKCreate>(LWKCreate());

  locator.registerSingleton<BDKCreate>(
    BDKCreate(
      walletsRepository: locator<WalletsRepository>(),
    ),
  );
  locator.registerSingleton<BDKSensitiveCreate>(
    BDKSensitiveCreate(
      walletsRepository: locator<WalletsRepository>(),
      bdkCreate: locator<BDKCreate>(),
    ),
  );
  locator.registerSingleton<LWKSensitiveCreate>(
    LWKSensitiveCreate(
      bdkSensitiveCreate: locator<BDKSensitiveCreate>(),
      lwkCreate: locator<LWKCreate>(),
    ),
  );

  locator.registerSingleton<WalletCreate>(
    WalletCreate(
      walletsRepository: locator<WalletsRepository>(),
      lwkCreate: locator<LWKCreate>(),
      bdkCreate: locator<BDKCreate>(),
      walletsStorageRepository: locator<WalletsStorageRepository>(),
    ),
  );

  locator.registerSingleton<WalletUpdate>(WalletUpdate());

  locator.registerSingleton<WalletAddress>(
    WalletAddress(
      bdkAddress: locator<BDKAddress>(),
      lwkAddress: locator<LWKAddress>(),
      walletsRepository: locator<WalletsRepository>(),
    ),
  );

  locator.registerSingleton<WalletSensitiveCreate>(
    WalletSensitiveCreate(
      bdkSensitiveCreate: locator<BDKSensitiveCreate>(),
    ),
  );
  // locator.registerSingleton<WalletSensitiveTx>(WalletSensitiveTx());

  locator.registerFactory<WalletSync>(
    () => WalletSync(
      bdkSync: locator<BDKSync>(),
      lwkSync: locator<LWKSync>(),
      walletsRepository: locator<WalletsRepository>(),
      networkRepository: locator<NetworkRepository>(),
    ),
  );

  locator.registerSingleton<WalletBalance>(
    WalletBalance(
      walletsRepository: locator<WalletsRepository>(),
      bdkBalance: locator<BDKBalance>(),
      lwkBalance: locator<LWKBalance>(),
    ),
  );

  locator.registerSingleton<WalletTx>(
    WalletTx(
      walletsRepository: locator<WalletsRepository>(),
      networkRepository: locator<NetworkRepository>(),
      walletAddress: locator<WalletAddress>(),
      walletSensitiveStorageRepository:
          locator<WalletSensitiveStorageRepository>(),
      walletUpdate: locator<WalletUpdate>(),
      bdkTransactions: locator<BDKTransactions>(),
      lwkTransactions: locator<LWKTransactions>(),
      bdkAddress: locator<BDKAddress>(),
      lwkAddress: locator<LWKAddress>(),
      bdkUtxo: locator<BDKUtxo>(),
      bdkSensitiveCreate: locator<BDKSensitiveCreate>(),
    ),
  );

  locator.registerSingleton<WalletNetwork>(
    WalletNetwork(
      networkRepository: locator<NetworkRepository>(),
      logger: locator<Logger>(),
      bdkNetwork: locator<BDKNetwork>(),
    ),
  );
}

Future _setupBlocs() async {
  locator.registerSingleton<HomeCubit>(
    HomeCubit(
      walletsStorageRepository: locator<WalletsStorageRepository>(),
    ),
  );

  locator.registerSingleton<SettingsCubit>(
    SettingsCubit(
      hiveStorage: locator<HiveStorage>(),
    ),
  );

  locator.registerSingleton<NetworkCubit>(
    NetworkCubit(
      hiveStorage: locator<HiveStorage>(),
      walletNetwork: locator<WalletNetwork>(),
    ),
  );

  locator.registerSingleton<NetworkFeesCubit>(
    NetworkFeesCubit(
      hiveStorage: locator<HiveStorage>(),
      mempoolAPI: locator<MempoolAPI>(),
      networkCubit: locator<NetworkCubit>(),
    ),
  );

  locator.registerSingleton<CurrencyCubit>(
    CurrencyCubit(
      hiveStorage: locator<HiveStorage>(),
      bbAPI: locator<BullBitcoinAPI>(),
    ),
  );

  await Future.delayed(1000.ms);

  locator.registerSingleton<WatchTxsBloc>(
    WatchTxsBloc(
      // isTestnet: locator<NetworkCubit>().state.testnet,
      swapBoltz: locator<SwapBoltz>(),
      walletTx: locator<WalletTx>(),
      homeCubit: locator<HomeCubit>(),
    ),
  );
}
