import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/create/bloc/state.dart';
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
    bool fromHome = false,
  }) : super(const CreateWalletState()) {
    createMne(fromHome: fromHome);
  }

  final SettingsCubit settingsCubit;
  final WalletSensitiveCreate walletSensCreate;
  final HiveStorage hiveStorage;
  final SecureStorage secureStorage;
  final WalletRepository walletRepository;
  final WalletSensitiveRepository walletSensRepository;

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

    if (fromHome) firstTime();
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

  void confirmClicked() async {
    if (state.mnemonic == null) return;
    emit(state.copyWith(saving: true, errSaving: ''));

    final network = settingsCubit.state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet;
    final mnemonic = state.mnemonic!.join(' ');
    final (seed, sErr) = await walletSensCreate.mnemonicSeed(mnemonic, network);
    if (sErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Creating Seed'));
    }
    final (wallet, wErr) = await walletSensCreate.oneFromBIP39(
      seed!,
      state.passPhrase,
      ScriptType.bip84,
      network,
      false,
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
        savedWallet: updatedWallet,
      ),
    );
  }

  void firstTime() async {
    if (state.mnemonic == null) return;
    emit(state.copyWith(saving: true, errSaving: ''));

    final mnemonic = state.mnemonic!.join(' ');
    final (seed, sErr) = await walletSensCreate.mnemonicSeed(
      mnemonic,
      BBNetwork.Mainnet,
    );
    if (sErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Creating Seed'));
    }
    var (wallet, wErr) = await walletSensCreate.oneFromBIP39(
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

    final ssErr = await walletSensRepository.newSeed(seed: seed, secureStore: secureStorage);
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
