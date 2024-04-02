import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/create/bloc/create_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  group('WatchTxs Bloc Test', () {
    late WalletRepository walletRepository;
    late WalletSensitiveRepository walletSensitiveRepository;
    late NetworkCubit networkCubit;
    late SwapBoltz swapBoltz;
    late HiveStorage hiveStorage;
    late SecureStorage secureStorage;
    late SettingsCubit settingsCubit;
    late WalletAddress walletAddress;
    late WalletTx walletTx;
    late CreateWalletCubit createWalletCubit;
    late HomeCubit homeCubit;
    late WatchTxsBloc watchTxsBloc;

    setUp(() {
      walletRepository = _WalletRepository();
      walletSensitiveRepository = _WalletSensitiveRepository();
      networkCubit = _NetworkCubit();
      swapBoltz = _SwapBoltz();
      hiveStorage = _HiveStorage();
      secureStorage = _SecureStorage();
      settingsCubit = _SettingsCubit();
      walletAddress = _WalletAddress();
      walletTx = _WalletTx();
      createWalletCubit = _CreateWalletCubit();

      watchTxsBloc = WatchTxsBloc(
        hiveStorage: hiveStorage,
        secureStorage: secureStorage,
        walletAddress: walletAddress,
        walletRepository: walletRepository,
        walletSensitiveRepository: walletSensitiveRepository,
        settingsCubit: settingsCubit,
        networkCubit: networkCubit,
        swapBoltz: swapBoltz,
        walletTx: walletTx,
        walletTransaction: walletTx,
      );

      homeCubit = HomeCubit(
        hiveStorage: hiveStorage,
        createWalletCubit: createWalletCubit,
        walletRepository: walletRepository,
      );

      watchTxsBloc.homeCubit = homeCubit;
    });

    blocTest(
      'claim test',
      build: () => watchTxsBloc,
      setUp: () {},
      act: (bloc) {},
      expect: () => [],
      verify: (bloc) {},
    );

    blocTest(
      'after claim - merge test',
      build: () => watchTxsBloc,
      setUp: () {},
      act: (bloc) {},
      expect: () => [],
      verify: (bloc) {},
    );

    blocTest(
      'expired test',
      build: () => watchTxsBloc,
      setUp: () {},
      act: (bloc) {},
      expect: () => [],
      verify: (bloc) {},
    );
  });
}

class _SettingsCubit extends Mock implements SettingsCubit {}

class _WalletAddress extends Mock implements WalletAddress {}

class _HiveStorage extends Mock implements HiveStorage {}

class _SecureStorage extends Mock implements SecureStorage {}

class _WalletRepository extends Mock implements WalletRepository {}

class _WalletSensitiveRepository extends Mock implements WalletSensitiveRepository {}

class _WalletTx extends Mock implements WalletTx {}

class _NetworkCubit extends Mock implements NetworkCubit {}

class _SwapBoltz extends Mock implements SwapBoltz {}

class _CreateWalletCubit extends Mock implements CreateWalletCubit {}

// const _wallet = Wallet(
//   network: BBNetwork.Testnet,
//   type: BBWalletType.words,
//   scriptType: ScriptType.bip84,
// );

// const _swapTest = SwapTx(
//   id: '01',
//   isSubmarine: false,
//   network: BBNetwork.Testnet,
//   redeemScript: '',
//   invoice: '',
//   outAmount: 50500,
//   scriptAddress: '',
//   electrumUrl: '',
//   boltzUrl: '',
// );

// const _tx = Transaction(
//   timestamp: 00,
//   txid: '012',
// );
