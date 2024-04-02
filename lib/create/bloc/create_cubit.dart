import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/create/bloc/state.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateWalletCubit extends Cubit<CreateWalletState> {
  CreateWalletCubit({
    required this.settingsCubit,
    required this.walletSensCreate,
    required this.hiveStorage,
    required this.secureStorage,
    required this.walletRepository,
    required this.walletSensRepository,
    required this.networkCubit,
    // bool fromHome = false,
    bool mainWallet = false,
  }) : super(
          CreateWalletState(
            mainWallet: mainWallet,
          ),
        ) {
    createMne();
  }

  final SettingsCubit settingsCubit;
  final WalletSensitiveCreate walletSensCreate;
  final HiveStorage hiveStorage;
  final SecureStorage secureStorage;
  final WalletRepository walletRepository;
  final WalletSensitiveRepository walletSensRepository;
  final NetworkCubit networkCubit;

  void createMne({bool fromHome = false}) async {
    emit(state.copyWith(creatingNmemonic: true));
    final (mnemonic, err) = await walletSensCreate.createMnemonic();
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

    // if (fromHome) firstTime();
  }

  void passPhraseChanged(String text) {
    emit(state.copyWith(passPhrase: text));
  }

  void walletLabelChanged(String text) {
    emit(state.copyWith(walletLabel: text));
  }
  // void _showSavingErr(String err) {
  //   emit(
  //     state.copyWith(
  //       errSaving: err,
  //       creatingNmemonic: false,
  //     ),
  //   );
  // }

  void toggleIsInstant(bool isInstant) => emit(state.copyWith(isInstant: isInstant));

  Future checkWalletLabel() async {
    final label = state.walletLabel;
    if (label == null || label == '')
      emit(state.copyWith(errSaving: 'Wallet Label is required'));
    else if (label.length < 3)
      emit(state.copyWith(errSaving: 'Wallet Label must be at least 3 characters'));
    else if (label.length > 20)
      emit(state.copyWith(errSaving: 'Wallet Label must be less than 20 characters'));
    else
      emit(state.copyWith(errSaving: ''));
  }

  void confirmClicked() async {
    if (state.mnemonic == null) return;
    emit(state.copyWith(saving: true, errSaving: ''));

    final createSecureAndMain = state.mainWallet;

    final label = state.walletLabel;
    if (label == null || label == '') {
      emit(state.copyWith(saving: false, errSaving: 'Wallet Label is required'));
      return;
    }

    final network = networkCubit.state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet;
    final mnemonic = state.mnemonic!.join(' ');
    final (seed, sErr) = await walletSensCreate.mnemonicSeed(mnemonic, network);
    if (sErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Creating Seed'));
      return;
    }
    final (wallet, wErr) = await walletSensCreate.oneFromBIP39(
      seed: seed!,
      passphrase: state.passPhrase,
      scriptType: ScriptType.bip84,
      network: network,
      walletType: state.isInstant ? BBWalletType.instant : BBWalletType.secure,
      // walletType: network,
      // false,
    );
    if (wErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Creating Wallet'));
      return;
    }
    final updatedWallet = (state.walletLabel != null && state.walletLabel != '')
        ? wallet!.copyWith(name: state.walletLabel)
        : wallet;

    final ssErr = await walletSensRepository.newSeed(seed: seed, secureStore: secureStorage);
    if (ssErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Saving Seed'));
      return;
    }
    if (state.passPhrase.isNotEmpty) {
      final passPhrase = state.passPhrase.isEmpty ? '' : state.passPhrase;

      final passphrase = Passphrase(
        passphrase: passPhrase,
        sourceFingerprint: wallet!.sourceFingerprint,
      );

      final ppErr = await walletSensRepository.newPassphrase(
        passphrase: passphrase,
        secureStore: secureStorage,
        seedFingerprintIndex: seed.getSeedStorageString(),
      );

      if (ppErr != null) {
        emit(
          state.copyWith(
            errSaving: ppErr.toString(),
            saving: false,
          ),
        );
        return;
      }
    }

    final wsErr = await walletRepository.newWallet(wallet: updatedWallet!, hiveStore: hiveStorage);
    if (wsErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Saving Wallet'));
    }
    clearSensitive();

    emit(
      state.copyWith(
        saving: false,
        saved: true,
        savedWallets: [updatedWallet],
      ),
    );
  }

  // void firstTime() async {
  //   if (state.mnemonic == null) return;
  //   emit(state.copyWith(saving: true, errSaving: ''));

  //   final mnemonic = state.mnemonic!.join(' ');
  //   final (seed, errMne) = await walletSensCreate.mnemonicSeed(
  //     mnemonic,
  //     BBNetwork.Mainnet,
  //   );
  //   if (errMne != null) {
  //     emit(state.copyWith(saving: false, errSaving: 'Error Creating Seed'));
  //   }
  //   var (walletSecure, errCreating1) = await walletSensCreate.oneFromBIP39(
  //     seed: seed!,
  //     passphrase: '',
  //     scriptType: ScriptType.bip84,
  //     network: BBNetwork.Mainnet,
  //     walletType: BBWalletType.secure,
  //   );
  //   if (errCreating1 != null) {
  //     emit(state.copyWith(saving: false, errSaving: 'Error Creating Wallet'));
  //     return;
  //   }

  //   // var (walletInstant, errCreating2) = await walletSensCreate.oneFromBIP39(
  //   //   seed: seed,
  //   //   passphrase: '',
  //   //   scriptType: ScriptType.bip84,
  //   //   network: BBNetwork.Mainnet,
  //   //   walletType: BBWalletType.instant,
  //   // );
  //   // if (errCreating2 != null) {
  //   //   emit(state.copyWith(saving: false, errSaving: 'Error Creating Wallet'));
  //   //   return;
  //   // }

  //   walletSecure = walletSecure!.copyWith(name: 'Bull Wallet');
  //   // walletInstant = walletInstant!.copyWith(name: 'Instant Wallet');

  //   final errSavingSeed =
  //       await walletSensRepository.newSeed(seed: seed, secureStore: secureStorage);
  //   if (errSavingSeed != null) {
  //     emit(state.copyWith(saving: false, errSaving: 'Error Saving Seed'));
  //   }

  //   final errSaving1 =
  //       await walletRepository.newWallet(wallet: walletSecure, hiveStore: hiveStorage);
  //   if (errSaving1 != null) {
  //     emit(state.copyWith(saving: false, errSaving: 'Error Saving Wallet'));
  //   }
  //   // final errSaving2 =
  //   //     await walletRepository.newWallet(wallet: walletInstant, hiveStore: hiveStorage);
  //   // if (errSaving2 != null) {
  //   //   emit(state.copyWith(saving: false, errSaving: 'Error Saving Wallet'));
  //   // }

  //   clearSensitive();

  //   emit(
  //     state.copyWith(
  //       savedWallets: [walletSecure],
  //       saving: false,
  //       saved: true,
  //     ),
  //   );
  // }

  void clearSensitive() {
    emit(state.copyWith(mnemonic: [], passPhrase: ''));
  }
}
