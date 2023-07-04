import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/deep_link.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/launcher.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/nfc.dart';
import 'package:bb_mobile/_pkg/storage/interface.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/delete.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/create/bloc/create_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

GetIt locator = GetIt.instance;

Future setupLocator({bool fromTest = false}) async {
  final secureStorage = SecureStorage();

  if (fromTest) {
    await secureStorage.deleteAll();
    // final appDocDir = await getApplicationDocumentsDirectory();
    // await appDocDir.delete(recursive: true);
    // await locator.reset();
  } else {
    final deepLink = DeepLink();
    locator.registerSingleton<DeepLink>(deepLink);
  }

  final http = Dio();

  final mempoolAPI = MempoolAPI(http);
  final fileStorage = FileStorage();
  locator.registerSingleton<IStorage>(secureStorage);
  locator.registerSingleton<WalletUpdate>(WalletUpdate());
  locator.registerSingleton<FileStorage>(fileStorage);

  // final coinGecko = CoinGecko();
  final bbAPI = BullBitcoinAPI(http);
  locator.registerSingleton<BullBitcoinAPI>(bbAPI);
  final walletcreate = WalletCreate();
  final walletread = WalletRead();

  final settings = SettingsCubit(
    walletCreate: walletcreate,
    storage: secureStorage,
    mempoolAPI: mempoolAPI,
    // coinGecko: coinGecko,
    bbAPI: bbAPI,
  );

  final homeCubit = HomeCubit(
    walletRead: walletread,
    storage: secureStorage,
    createWalletCubit: CreateWalletCubit(
      walletCreate: walletcreate,

      settingsCubit: settings,
      walletUpdate: locator<WalletUpdate>(),
      storage: locator<IStorage>(),
      // fromHome: true,
    ),
  );

  settings.homeCubit = homeCubit;
  settings.loadTimer();

  locator.registerSingleton<SettingsCubit>(settings);

  locator.registerSingleton<MempoolAPI>(mempoolAPI);
  locator.registerSingleton<WalletDelete>(WalletDelete());
  locator.registerSingleton<WalletCreate>(walletcreate);
  locator.registerSingleton<WalletRead>(walletread);
  // final walletUtils = WalletService(walletStorage);
  locator.registerSingleton<Barcode>(Barcode());
  locator.registerSingleton<Launcher>(Launcher());

  locator.registerSingleton<NFCPicker>(NFCPicker());
  locator.registerSingleton<FilePick>(FilePick());

  locator.registerSingleton<HomeCubit>(homeCubit);

  // locator.registerSingleton<WalletService>(walletUtils);

  // locator.registerSingleton<BdkFlutter>(BdkFlutter());
}
