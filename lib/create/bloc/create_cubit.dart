import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/create/bloc/state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateWalletCubit extends Cubit<CreateWalletState> {
  CreateWalletCubit({
    required this.settingsCubit,
    required this.walletCreate,
    required this.hiveStorage,
    required this.secureStorage,
    required this.walletRepository,
    bool fromHome = false,
  }) : super(const CreateWalletState()) {
    createMne(fromHome: fromHome);
  }

  final SettingsCubit settingsCubit;
  final WalletCreate walletCreate;
  final HiveStorage hiveStorage;
  final SecureStorage secureStorage;
  final WalletRepository walletRepository;

  void createMne({bool fromHome = false}) async {
    emit(state.copyWith(creatingNmemonic: true));
    final (mnemonic, err) = await walletCreate.createMnemonic();
    if (err != null) {
      emit(
        state.copyWith(
          errCreatingNmemonic: err.toString(),
          creatingNmemonic: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        mnemonic: mnemonic,
        creatingNmemonic: false,
      ),
    );

    if (fromHome) firstTime();
  }

  void passPhraseChanged(String text) {
    emit(state.copyWith(passPhrase: text));
  }

  // void _showSavingErr(String err) {
  //   emit(
  //     state.copyWith(
  //       errSaving: err,
  //       creatingNmemonic: false,
  //     ),
  //   );
  // }

  void confirmClicked() async {
    if (state.mnemonic == null) return;
    emit(state.copyWith(saving: true, errSaving: ''));

    final network = settingsCubit.state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet;
    final mnemonic = state.mnemonic!.join(' ');
    final (seed, sErr) = await walletCreate.mnemonicSeed(mnemonic, network);
    if (sErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Creating Seed'));
    }
    final (wallet, wErr) = await walletCreate.oneFromBIP39(
      seed!,
      state.passPhrase,
      ScriptType.bip84,
      network,
      false,
    );
    if (wErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Creating Wallet'));
    }

    final ssErr = await walletRepository.newSeed(seed: seed, secureStore: secureStorage);
    if (ssErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Saving Seed'));
    }
    final wsErr = await walletRepository.newWallet(wallet: wallet!, hiveStore: hiveStorage);
    if (wsErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Saving Wallet'));
    }
    clearSensitive();

    emit(
      state.copyWith(
        saving: false,
        saved: true,
        savedWallet: wallet,
      ),
    );
  }

  void firstTime() async {
    if (state.mnemonic == null) return;
    emit(state.copyWith(saving: true, errSaving: ''));

    final mnemonic = state.mnemonic!.join(' ');
    final (seed, sErr) = await walletCreate.mnemonicSeed(
      mnemonic,
      BBNetwork.Mainnet,
    );
    if (sErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Creating Seed'));
    }
    var (wallet, wErr) = await walletCreate.oneFromBIP39(
      seed!,
      '',
      ScriptType.bip84,
      BBNetwork.Mainnet,
      false,
    );
    if (wErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Creating Wallet'));
    }

    const label = 'Bull Wallet';
    wallet = wallet!.copyWith(name: label);

    final ssErr = await walletRepository.newSeed(seed: seed, secureStore: secureStorage);
    if (ssErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Saving Seed'));
    }
    final wsErr = await walletRepository.newWallet(wallet: wallet, hiveStore: hiveStorage);
    if (wsErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Saving Wallet'));
    }

    clearSensitive();

    emit(
      state.copyWith(
        savedWallet: wallet,
        saving: false,
        saved: true,
      ),
    );
  }

  void clearSensitive() {
    emit(state.copyWith(mnemonic: [], passPhrase: ''));
  }
}
