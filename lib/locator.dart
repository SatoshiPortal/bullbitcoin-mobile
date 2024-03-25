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
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_pkg/wallet/utxo.dart';
import 'package:bb_mobile/create/bloc/create_cubit.dart';
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
  final (secureStorage, hiveStorage) = await setupStorage();

  if (fromTest) {
    await secureStorage.deleteAll();
    // final appDocDir = await getApplicationDocumentsDirectory();
    // await appDocDir.delete(recursive: true);
    // await locator.reset();
  } else {
    final deepLink = DeepLink();
    locator.registerSingleton<DeepLink>(deepLink);
  }

  locator.registerSingleton<Logger>(Logger());
  locator.registerSingleton<Lighting>(Lighting(hiveStorage: hiveStorage));

  locator.registerSingleton<SecureStorage>(secureStorage);
  locator.registerSingleton<HiveStorage>(hiveStorage);
  locator.registerSingleton<IStorage>(hiveStorage);

  final http = Dio();

  final mempoolAPI = MempoolAPI(http);
  final bbAPI = BullBitcoinAPI(http);
  locator.registerSingleton<BullBitcoinAPI>(bbAPI);

  final fileStorage = FileStorage();
  final walletRepository = WalletRepository();

  locator.registerSingleton<FileStorage>(fileStorage);
  locator.registerSingleton<WalletRepository>(walletRepository);

  locator.registerSingleton<WalletUpdate>(WalletUpdate());
  locator.registerSingleton<WalletBalance>(WalletBalance());
  final walletTx = WalletTx();
  final walletAddress = WalletAddress();
  locator.registerSingleton<WalletTx>(walletTx);
  locator.registerSingleton<WalletAddress>(walletAddress);
  locator.registerSingleton<WalletUtxo>(WalletUtxo());
  final boltz = SwapBoltz(secureStorage: secureStorage);
  locator.registerSingleton<SwapBoltz>(boltz);

  // final walletSync = WalletSync();

  final walletCreate = WalletCreate();
  final walletSensCreate = WalletSensitiveCreate();
  final walletSensTx = WalletSensitiveTx();
  final walletSensRepo = WalletSensitiveRepository();

  final networkCubit = NetworkCubit(
    hiveStorage: hiveStorage,
    walletSync: WalletSync(),
  );
  locator.registerSingleton<NetworkCubit>(networkCubit);

  final networkFeesCubit = NetworkFeesCubit(
    hiveStorage: hiveStorage,
    mempoolAPI: mempoolAPI,
    networkCubit: networkCubit,
  );
  locator.registerSingleton<NetworkFeesCubit>(networkFeesCubit);

  final currencyCubit = CurrencyCubit(
    hiveStorage: hiveStorage,
    bbAPI: bbAPI,
  );
  locator.registerSingleton<CurrencyCubit>(currencyCubit);

  final settings = SettingsCubit(
    walletSync: WalletSync(),
    hiveStorage: hiveStorage,
    mempoolAPI: mempoolAPI,
    bbAPI: bbAPI,
  );

  final swap = WatchTxsBloc(
    hiveStorage: hiveStorage,
    secureStorage: secureStorage,
    walletAddress: walletAddress,
    walletRepository: walletRepository,
    walletSensitiveRepository: walletSensRepo,
    settingsCubit: settings,
    networkCubit: networkCubit,
    swapBoltz: boltz,
    walletTx: walletTx,
    walletTransaction: walletTx,
  );

  final homeCubit = HomeCubit(
    // walletSync: walletSync,
    hiveStorage: locator<HiveStorage>(),
    createWalletCubit: CreateWalletCubit(
      walletSensCreate: walletSensCreate,
      settingsCubit: settings,
      walletRepository: locator<WalletRepository>(),
      hiveStorage: hiveStorage,
      secureStorage: secureStorage,
      walletSensRepository: walletSensRepo,
      networkCubit: locator<NetworkCubit>(),
    ),
    walletRepository: locator<WalletRepository>(),
  );

  swap.homeCubit = homeCubit;
  locator.registerSingleton<WatchTxsBloc>(swap);

  settings.homeCubit = homeCubit;
  networkCubit.homeCubit = homeCubit;
  settings.loadTimer();

  locator.registerSingleton<SettingsCubit>(settings);
  locator.registerSingleton<WalletSensitiveCreate>(walletSensCreate);
  locator.registerSingleton<WalletSensitiveTx>(walletSensTx);
  locator.registerSingleton<WalletSensitiveRepository>(walletSensRepo);

  locator.registerSingleton<MempoolAPI>(mempoolAPI);
  locator.registerSingleton<WalletCreate>(walletCreate);
  locator.registerFactory<WalletSync>(() => WalletSync());
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

  locator.registerSingleton<HomeCubit>(homeCubit);
}
