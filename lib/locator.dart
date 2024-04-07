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
import 'package:bb_mobile/_pkg/wallet/bdk/sync.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/utxo.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/address.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/balance.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/create.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sync.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/network.dart';
import 'package:bb_mobile/_pkg/wallet/repository/network.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/transaction_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/import/bloc/words_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/network_fees_cubit.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

const bbVersion = '0.1.98-1.1';

GetIt locator = GetIt.instance;

Future setupLocator({bool fromTest = false}) async {
  if (fromTest) return;

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
  // locator.registerSingleton<HomeRepository>(HomeRepository());
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
}

Future _setupWalletServices() async {
  locator.registerFactory<BDKSync>(() => BDKSync());
  locator.registerFactory<LWKSync>(() => LWKSync());
  locator.registerSingleton<BDKBalance>(BDKBalance());
  locator.registerSingleton<LWKBalance>(LWKBalance());
  locator.registerSingleton<BDKNetwork>(BDKNetwork());
  locator.registerSingleton<BDKAddress>(BDKAddress());
  locator.registerSingleton<LWKAddress>(LWKAddress());
  locator.registerSingleton<BDKTransactions>(BDKTransactions());
  locator.registerSingleton<LWKTransactions>(LWKTransactions());
  locator.registerSingleton<BDKUtxo>(BDKUtxo());
  locator.registerSingleton<LWKCreate>(LWKCreate());
  locator.registerSingleton<BDKCreate>(BDKCreate());

  locator.registerSingleton<WalletCreatee>(
    WalletCreatee(
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
    WalletSensitiveCreate(walletsRepository: locator<WalletsRepository>()),
  );
  locator.registerSingleton<WalletSensitiveTx>(WalletSensitiveTx());
  locator.registerSingleton<WalletCreate>(
    WalletCreate(
      walletsRepository: locator<WalletsRepository>(),
    ),
  );

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

  locator.registerSingleton<WalletTxx>(
    WalletTxx(
      walletsRepository: locator<WalletsRepository>(),
      networkRepository: locator<NetworkRepository>(),
      walletAddress: locator<WalletAddress>(),
      walletSensitiveCreate: locator<WalletSensitiveCreate>(),
      walletSensitiveStorageRepository: locator<WalletSensitiveStorageRepository>(),
      walletUpdate: locator<WalletUpdate>(),
      bdkTransactions: locator<BDKTransactions>(),
      lwkTransactions: locator<LWKTransactions>(),
      bdkAddress: locator<BDKAddress>(),
      lwkAddress: locator<LWKAddress>(),
      bdkUtxo: locator<BDKUtxo>(),
    ),
  );

  locator.registerSingleton<SwapBoltz>(SwapBoltz(secureStorage: locator<SecureStorage>()));
  locator.registerSingleton<WalletNetwork>(
    WalletNetwork(
      networkRepository: locator<NetworkRepository>(),
      logger: locator<Logger>(),
      bdkNetwork: locator<BDKNetwork>(),
    ),
  );
}

Future _setupAppServices() async {
  final deepLink = DeepLink();
  locator.registerSingleton<DeepLink>(deepLink);
  locator.registerSingleton<Logger>(Logger());
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

Future _setupBlocs() async {
  final settings = SettingsCubit(
    walletSync: locator<WalletSync>(),
    hiveStorage: locator<HiveStorage>(),
    mempoolAPI: locator<MempoolAPI>(),
    bbAPI: locator<BullBitcoinAPI>(),
  );

  locator.registerSingleton<NetworkCubit>(
    NetworkCubit(
      hiveStorage: locator<HiveStorage>(),
      walletNetwork: locator<WalletNetwork>(),
      networkRepository: locator<NetworkRepository>(),
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

  final swap = WatchTxsBloc(
    hiveStorage: locator<HiveStorage>(),
    secureStorage: locator<SecureStorage>(),
    walletAddress: locator<WalletAddress>(),
    walletsStorageRepository: locator<WalletsStorageRepository>(),
    walletSensitiveRepository: WalletSensitiveStorageRepository(
      secureStorage: locator<SecureStorage>(),
    ),
    settingsCubit: settings,
    networkCubit: locator<NetworkCubit>(),
    swapBoltz: locator<SwapBoltz>(),
    walletTx: locator<WalletTxx>(),
  );

  final homeCubit = HomeCubit(
    walletsStorageRepository: locator<WalletsStorageRepository>(),
  );

  swap.homeCubit = homeCubit;
  locator.registerSingleton<WatchTxsBloc>(swap);

  settings.homeCubit = homeCubit;
  locator<NetworkCubit>().homeCubit = homeCubit;
  settings.loadTimer();

  locator.registerSingleton<SettingsCubit>(settings);

  locator.registerSingleton<HomeCubit>(homeCubit);
}
