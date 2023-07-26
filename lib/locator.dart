import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/deep_link.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/launcher.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/mnemonic_word.dart';
import 'package:bb_mobile/_pkg/nfc.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/delete.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/create/bloc/create_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/import/bloc/words_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

const bbVersion = '0.1.5';

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

  locator.registerSingleton<SecureStorage>(secureStorage);
  locator.registerSingleton<HiveStorage>(hiveStorage);
  locator.registerSingleton<IStorage>(hiveStorage);

  final http = Dio();

  final mempoolAPI = MempoolAPI(http);
  final bbAPI = BullBitcoinAPI(http);
  locator.registerSingleton<BullBitcoinAPI>(bbAPI);

  final fileStorage = FileStorage();
  locator.registerSingleton<FileStorage>(fileStorage);

  locator.registerSingleton<WalletUpdate>(WalletUpdate());
  final walletcreate = WalletCreate();
  final walletread = WalletRead();

  final settings = SettingsCubit(
    walletCreate: walletcreate,
    storage: hiveStorage,
    mempoolAPI: mempoolAPI,
    bbAPI: bbAPI,
  );

  final homeCubit = HomeCubit(
    walletRead: walletread,
    storage: locator<HiveStorage>(),
    createWalletCubit: CreateWalletCubit(
      walletCreate: walletcreate,
      settingsCubit: settings,
      walletRepository: locator<WalletRepository>(),
      hiveStorage: hiveStorage,
      secureStorage: secureStorage,
    ),
  );

  settings.homeCubit = homeCubit;
  settings.loadTimer();

  locator.registerSingleton<SettingsCubit>(settings);

  locator.registerSingleton<MempoolAPI>(mempoolAPI);
  locator.registerSingleton<WalletDelete>(WalletDelete());
  locator.registerSingleton<WalletCreate>(walletcreate);
  locator.registerSingleton<WalletRead>(walletread);
  locator.registerSingleton<Barcode>(Barcode());
  locator.registerSingleton<Launcher>(Launcher());
  locator.registerSingleton<NFCPicker>(NFCPicker());
  locator.registerSingleton<FilePick>(FilePick());
  locator.registerSingleton<WordsCubit>(
    WordsCubit(
      mnemonicWords: MnemonicWords(),
    ),
  );

  locator.registerSingleton<HomeCubit>(homeCubit);
}
