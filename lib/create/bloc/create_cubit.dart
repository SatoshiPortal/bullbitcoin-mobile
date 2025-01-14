import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sensitive_create.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/create/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateWalletCubit extends Cubit<CreateWalletState> {
  CreateWalletCubit({
    required WalletSensitiveCreate walletSensCreate,
    required WalletsStorageRepository walletsStorageRepository,
    required WalletSensitiveStorageRepository walletSensRepository,
    required NetworkRepository networkRepository,
    required WalletCreate walletCreate,
    required BDKSensitiveCreate bdkSensitiveCreate,
    required LWKSensitiveCreate lwkSensitiveCreate,
    bool mainWallet = false,
  })  : _lwkSensitiveCreate = lwkSensitiveCreate,
        _bdkSensitiveCreate = bdkSensitiveCreate,
        _walletCreate = walletCreate,
        _walletSensRepository = walletSensRepository,
        _walletsStorageRepository = walletsStorageRepository,
        _networkRepository = networkRepository,
        _walletSensCreate = walletSensCreate,
        super(
          CreateWalletState(mainWallet: mainWallet),
        ) {
    createMne();
  }

  final WalletSensitiveCreate _walletSensCreate;
  final WalletsStorageRepository _walletsStorageRepository;
  final WalletSensitiveStorageRepository _walletSensRepository;

  final WalletCreate _walletCreate;
  final BDKSensitiveCreate _bdkSensitiveCreate;
  final LWKSensitiveCreate _lwkSensitiveCreate;
  final NetworkRepository _networkRepository;

  Future<void> createMne({bool fromHome = false}) async {
    emit(state.copyWith(creatingNmemonic: true));
    final (mnemonic, err) = await _walletSensCreate.createMnemonic();
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
  }

  void passPhraseChanged(String text) {
    emit(state.copyWith(passPhrase: text));
  }

  void walletLabelChanged(String text) {
    emit(state.copyWith(walletLabel: text));
  }

  void toggleIsInstant(bool isInstant) =>
      emit(state.copyWith(isInstant: isInstant));

  Future checkWalletLabel() async {
    if (state.mainWallet) return;
    final label = state.walletLabel;
    if (label == null || label == '') {
      emit(state.copyWith(errSaving: 'Wallet Label is required'));
    } else if (label.length < 3) {
      emit(
        state.copyWith(
          errSaving: 'Wallet Label must be at least 3 characters',
        ),
      );
    } else if (label.length > 20) {
      emit(
        state.copyWith(
          errSaving: 'Wallet Label must be less than 20 characters',
        ),
      );
    } else {
      emit(state.copyWith(errSaving: ''));
    }
  }

  Future<void> confirmClicked() async {
    if (state.mnemonic == null) return;
    emit(state.copyWith(saving: true, errSaving: ''));

    final label = state.walletLabel;
    if (!state.mainWallet) {
      if (label == null || label == '') {
        emit(
          state.copyWith(
            saving: false,
            errSaving: 'Wallet Label is required',
          ),
        );
        return;
      }
    }

    final network = _networkRepository.getBBNetwork;

    final mnemonic = state.mnemonic!.join(' ');
    final (seed, sErr) =
        await _walletSensCreate.mnemonicSeed(mnemonic, network);
    if (sErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Creating Seed'));
      return;
    }
    var (wallet, wErr) = await _bdkSensitiveCreate.oneFromBIP39(
      seed: seed!,
      passphrase: state.passPhrase,
      scriptType: ScriptType.bip84,
      network: network,
      walletType: BBWalletType.main,
      walletCreate: _walletCreate,
    );
    if (wErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Creating Wallet'));
      return;
    }

    if (state.mainWallet) wallet = wallet!.copyWith(mainWallet: true);

    var walletLabel = state.walletLabel ?? '';
    if (state.mainWallet) walletLabel = wallet!.creationName();
    final updatedWallet = wallet!.copyWith(name: walletLabel);

    final ssErr = await _walletSensRepository.newSeed(seed: seed);
    if (ssErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Saving Seed'));
      return;
    }
    if (state.passPhrase.isNotEmpty) {
      final passPhrase = state.passPhrase.isEmpty ? '' : state.passPhrase;

      final passphrase = Passphrase(
        passphrase: passPhrase,
        sourceFingerprint: wallet.sourceFingerprint,
      );

      final ppErr = await _walletSensRepository.newPassphrase(
        passphrase: passphrase,
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

    final wsErr = await _walletsStorageRepository.newWallet(updatedWallet);
    if (wsErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Saving Wallet'));
    }

    Wallet? liqWallet;
    if (state.mainWallet) {
      liqWallet = await _createLiquid(
        seed: seed,
        passPhrase: state.passPhrase,
        network: network,
      );
    }

    clearSensitive();

    emit(
      state.copyWith(
        saving: false,
        saved: true,
        savedWallets: [
          updatedWallet,
          if (liqWallet != null) liqWallet,
        ],
      ),
    );
  }

  Future<Wallet?> _createLiquid({
    required Seed seed,
    required String passPhrase,
    required BBNetwork network,
  }) async {
    var (wallet, wErr) = await _lwkSensitiveCreate.oneLiquidFromBIP39(
      seed: seed,
      passphrase: state.passPhrase,
      scriptType: ScriptType.bip84,
      network: network,
      walletType: BBWalletType.main,
      walletCreate: _walletCreate,
    );
    if (wErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Creating Wallet'));
      return null;
    }

    wallet = wallet!.copyWith(mainWallet: true);

    var walletLabel = state.walletLabel ?? '';
    if (state.mainWallet) walletLabel = wallet.creationName();
    final updatedWallet = wallet.copyWith(name: walletLabel);

    final wsErr = await _walletsStorageRepository.newWallet(updatedWallet);
    if (wsErr != null) {
      emit(state.copyWith(saving: false, errSaving: 'Error Saving Wallet'));
    }

    return updatedWallet;
  }

  void clearSensitive() {
    emit(state.copyWith(mnemonic: [], passPhrase: ''));
  }
}
