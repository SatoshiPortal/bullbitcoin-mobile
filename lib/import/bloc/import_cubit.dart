import 'dart:convert';

import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/nfc.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/create.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/testable_wallets.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bb_mobile/import/bloc/import_state.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportWalletCubit extends Cubit<ImportState> {
  ImportWalletCubit({
    required this.barcode,
    required this.filePicker,
    required this.nfc,
    required this.walletCreate,
    required this.walletSensCreate,
    required this.walletsStorageRepository,
    required this.walletSensRepository,
    required this.networkCubit,
    required this.bdkCreate,
    required this.bdkSensitiveCreate,
    bool mainWallet = false,
  }) : super(
          ImportState(
            mainWallet: mainWallet,
            words12: [
              ...importW(r2),
            ],
          ),
        ) {
    // clearErrors();
    // reset();
    // emit(state.copyWith(words12: [...emptyWords12], words24: [...emptyWords24]));

    if (mainWallet) recoverClicked();
  }

  final Barcode barcode;
  final FilePick filePicker;
  final NFCPicker nfc;

  final WalletCreate walletCreate;
  final BDKCreate bdkCreate;
  final BDKSensitiveCreate bdkSensitiveCreate;
  final WalletSensitiveCreate walletSensCreate;

  final WalletsStorageRepository walletsStorageRepository;
  final WalletSensitiveStorageRepository walletSensRepository;
  final NetworkCubit networkCubit;

  void backClicked() {
    switch (state.importStep) {
      case ImportSteps.import12Words:
      case ImportSteps.import24Words:
        reset();
        clearErrors();
        emit(
          state.copyWith(
            importStep: ImportSteps.selectCreateType,
          ),
        );
      case ImportSteps.selectImportType:
      case ImportSteps.importXpub:
      case ImportSteps.scanningNFC:
      case ImportSteps.scanningWallets:
        stopScanningNFC();
        reset();
        clearErrors();
        emit(
          state.copyWith(
            importStep: ImportSteps.selectCreateType,
            importType: ImportTypes.notSelected,
          ),
        );

      case ImportSteps.selectWalletFormat:
        if (state.importType == ImportTypes.xpub)
          emit(
            state.copyWith(
              importStep: ImportSteps.importXpub,
              importType: state.importType,
            ),
          );
        else if (state.importType == ImportTypes.words12)
          emit(
            state.copyWith(
              importStep: ImportSteps.import12Words,
              importType: state.importType,
              words12: [...emptyWords12],
            ),
          );
        else if (state.importType == ImportTypes.words24)
          emit(
            state.copyWith(
              importStep: ImportSteps.import24Words,
              importType: state.importType,
              words24: [...emptyWords24],
            ),
          );
        else if (state.importType == ImportTypes.coldcard)
          emit(
            state.copyWith(
              importStep: ImportSteps.importXpub,
              importType: state.importType,
            ),
          );
        emit(state.copyWith(errSavingWallet: ''));

        stopScanningNFC();

      default:
        break;
    }
  }

  void importClicked() {
    emit(
      state.copyWith(
        importStep: ImportSteps.importXpub,
        importType: ImportTypes.xpub,
      ),
    );
  }

  void recoverClicked() {
    emit(
      state.copyWith(
        importStep: ImportSteps.import12Words,
        importType: ImportTypes.words12,
      ),
    );
  }

  void recoverClicked24() {
    emit(
      state.copyWith(
        importStep: ImportSteps.import24Words,
        importType: ImportTypes.words24,
      ),
    );
  }

  void scanQRClicked() async {
    emit(state.copyWith(loadingFile: true));
    final (res, err) = await barcode.scan();
    if (err != null) {
      emit(
        state.copyWith(
          errImporting: err.toString(),
          loadingFile: false,
        ),
      );
      return;
    }

    if (state.importStep == ImportSteps.importXpub) emit(state.copyWith(xpub: res!));

    emit(state.copyWith(loadingFile: false));
  }

  void wordChanged(int idx, String text, bool tapped) {
    final importType = state.importType;
    if (importType == ImportTypes.words12) {
      final words12 = state.words12.toList();
      words12[idx] = (word: text, tapped: tapped);
      emit(
        state.copyWith(
          words12: words12,
        ),
      );
    }

    if (importType == ImportTypes.words24) {
      final words24 = state.words24.toList();
      words24[idx] = (word: text, tapped: tapped);
      emit(
        state.copyWith(
          words24: words24,
        ),
      );
    }
  }

  void clearUntappedWords() {
    final words12 = state.words12.toList();
    final words24 = state.words24.toList();

    for (int i = 0; i < words12.length; i++)
      if (!words12[i].tapped) words12[i] = (word: '', tapped: false);

    for (int i = 0; i < words24.length; i++)
      if (!words24[i].tapped) words24[i] = (word: '', tapped: false);

    emit(
      state.copyWith(
        words12: words12,
        words24: words24,
      ),
    );
  }

  void passPhraseChanged(String text) {
    emit(state.copyWith(passPhrase: text));
  }

  void walletLabelChanged(String text) {
    emit(state.copyWith(walletLabel: text));
  }

  void xpubChanged(String text) {
    emit(state.copyWith(xpub: text));
  }

  void descriptorChanged(String text) {
    emit(state.copyWith(manualPublicDescriptor: text));
  }

  void cDescriptorChanged(String text) {
    emit(state.copyWith(manualPublicChangeDescriptor: text));
  }

  void combinedDescriptorChanged(String text) {
    emit(
      state.copyWith(manualCombinedPublicDescriptor: text),
    );
    final desc = splitCombinedChanged(text, false);
    final cdesc = splitCombinedChanged(text, true);
    emit(
      state.copyWith(
        manualPublicDescriptor: desc,
        manualPublicChangeDescriptor: cdesc,
      ),
    );
  }

  void fingerprintChanged(String text) {
    emit(state.copyWith(fingerprint: text));
  }

  void customDerivationChanged(String text) {
    emit(state.copyWith(customDerivation: text));
  }

  void coldCardNFCClicked() async {
    emit(
      state.copyWith(
        importStep: ImportSteps.scanningNFC,
        loadingFile: true,
        errLoadingFile: '',
      ),
    );

    final err = await nfc.startSession(coldCardNFCReceived);
    if (err != null) {
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: err.toString(),
          loadingFile: false,
        ),
      );

      final errStopping = nfc.stopSession();
      if (errStopping != null)
        emit(
          state.copyWith(
            errLoadingFile: errStopping.toString(),
            loadingFile: false,
          ),
        );
    }
  }

  void stopScanningNFC() async {
    final err = nfc.stopSession();
    if (err != null) emit(state.copyWith(errLoadingFile: err.toString()));
    emit(state.copyWith(loadingFile: false));
  }

  void coldCardNFCReceived(String jsnStr) async {
    final ccObj = jsonDecode(jsnStr) as Map<String, dynamic>;
    final coldcard = ColdCard.fromJson(ccObj);

    emit(state.copyWith(coldCard: coldcard, importType: ImportTypes.coldcard));

    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) {
      final errStoppping = nfc.stopSession();
      if (errStoppping != null)
        emit(
          state.copyWith(
            errLoadingFile: errStoppping.toString(),
            loadingFile: false,
          ),
        );
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: state.errImporting,
          loadingFile: false,
        ),
      );

      return;
    }

    emit(
      state.copyWith(
        importStep: ImportSteps.scanningWallets,
        loadingFile: false,
        importType: ImportTypes.coldcard,
      ),
    );
  }

  void coldCardFileClicked() async {
    emit(
      state.copyWith(
        loadingFile: true,
        errLoadingFile: '',
      ),
    );
    final (file, err) = await filePicker.pickFile();
    if (err != null) {
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: err.toString(),
          loadingFile: false,
        ),
      );
      return;
    }

    final ccObj = jsonDecode(file!) as Map<String, dynamic>;

    final coldcard = ColdCard.fromJson(ccObj);

    emit(state.copyWith(coldCard: coldcard, importType: ImportTypes.coldcard));

    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) {
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: state.errImporting,
          loadingFile: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        importStep: ImportSteps.scanningWallets,
        loadingFile: false,
        importType: ImportTypes.coldcard,
      ),
    );
  }

  void xpubSaveClicked() async {
    await checkWalletLabel();
    if (state.errSavingWallet.isNotEmpty) return;

    emit(state.copyWith(errImporting: ''));
    if (state.xpub.isEmpty) {
      emit(state.copyWith(errImporting: 'Please enter xpub'));
      return;
    }

    emit(
      state.copyWith(
        tempXpub: state.xpub,
        xpub: state.xpub,
        importType: ImportTypes.xpub,
      ),
    );

    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) return;

    emit(state.copyWith(importStep: ImportSteps.scanningWallets));
  }

  void recoverWalletClicked() async {
    await checkWalletLabel();
    if (state.errSavingWallet.isNotEmpty) return;

    final words = state.importType == ImportTypes.words12 ? state.words12 : state.words24;

    emit(state.copyWith(errImporting: ''));
    for (final word in words)
      if (word.word.isEmpty) {
        emit(state.copyWith(errImporting: 'Please fill all words'));
        return;
      }
    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) return;

    emit(state.copyWith(importStep: ImportSteps.scanningWallets));
  }

  Future _updateWalletDetailsForSelection() async {
    try {
      final type = state.importType;

      final wallets = <Wallet>[];
      final network = networkCubit.state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet;

      switch (type) {
        case ImportTypes.words12:
          final mnemonic = state.words12.map((_) => _.word).join(' ');
          final passphrase = state.passPhrase.isEmpty ? '' : state.passPhrase;
          final (ws, wErrs) = await bdkSensitiveCreate.allFromBIP39(
            mnemonic: mnemonic,
            passphrase: passphrase,
            network: network,
            isImported: true,
            walletCreate: walletCreate,
          );
          if (wErrs != null) {
            emit(state.copyWith(errImporting: 'Error creating Wallets from Bip 39'));
            return;
          }
          wallets.addAll(ws!);
        case ImportTypes.words24:
          final mnemonic = state.words24.map((_) => _.word).join(' ');
          final passphrase = state.passPhrase.isEmpty ? '' : state.passPhrase;

          final (ws, wErrs) = await bdkSensitiveCreate.allFromBIP39(
            mnemonic: mnemonic,
            passphrase: passphrase,
            network: network,
            isImported: true,
            walletCreate: walletCreate,
          );
          if (wErrs != null) {
            emit(state.copyWith(errImporting: 'Error creating Wallets from Bip 39'));
            return;
          }
          wallets.addAll(ws!);

        case ImportTypes.xpub:
          if (state.xpub.contains('[')) {
            // has origin info
            final (wxpub, wErrs) = await bdkCreate.oneFromXpubWithOrigin(
              state.xpub,
            );
            if (wErrs != null) {
              emit(state.copyWith(errImporting: 'Error creating Wallets from Xpub'));
              return;
            }
            scriptTypeChanged(wxpub!.scriptType);
            wallets.addAll([wxpub]);
          } else {
            final (wxpub, wErrs) = await bdkCreate.oneFromSlip132Pub(
              state.xpub,
            );
            if (wErrs != null) {
              emit(state.copyWith(errImporting: 'Error creating Wallets from Xpub'));
              return;
            }
            scriptTypeChanged(wxpub!.scriptType);
            wallets.addAll([wxpub]);
          }
        case ImportTypes.coldcard:
          final coldcard = state.coldCard!;

          final (cws, wErrs) = await bdkCreate.allFromColdCard(
            coldcard,
            network,
          );
          if (wErrs != null) {
            emit(state.copyWith(errImporting: 'Error creating Wallets from ColdCard'));
            return;
          }
          wallets.addAll(cws!);

        default:
          break;
      }

      if (wallets.isEmpty) throw 'Unable to create a wallet';

      emit(state.copyWith(walletDetails: wallets));
    } catch (e) {
      emit(state.copyWith(errImporting: e.toString()));
    }
  }

  void syncingComplete() {
    emit(
      state.copyWith(
        importStep: ImportSteps.selectWalletFormat,
      ),
    );
  }

  void scriptTypeChanged(ScriptType scriptType) {
    emit(state.copyWith(scriptType: scriptType));
  }

  Future checkWalletLabel() async {
    final label = state.walletLabel;
    if (label == null || label == '')
      emit(state.copyWith(errSavingWallet: 'Wallet Label is required'));
    else if (label.length < 3)
      emit(state.copyWith(errSavingWallet: 'Wallet Label must be at least 3 characters'));
    else if (label.length > 20)
      emit(state.copyWith(errSavingWallet: 'Wallet Label must be less than 20 characters'));
    else
      emit(state.copyWith(errSavingWallet: ''));
  }

  void saveClicked() async {
    emit(state.copyWith(savingWallet: true, errSavingWallet: ''));

    final createSecureAndMain = state.mainWallet;

    Wallet? selectedWallet = state.getSelectWalletDetails();
    if (selectedWallet == null) return;
    selectedWallet = (state.walletLabel != null && state.walletLabel != '')
        ? selectedWallet.copyWith(name: state.walletLabel)
        : selectedWallet;

    final network = networkCubit.state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet;

    if (selectedWallet.type == BBWalletType.words) {
      final mnemonic = (state.importType == ImportTypes.words12)
          ? state.words12.map((_) => _.word).join(' ')
          : state.words24.map((_) => _.word).join(' ');
      final (seed, sErr) = await walletSensCreate.mnemonicSeed(mnemonic, network);
      if (sErr != null) {
        emit(state.copyWith(errImporting: 'Error creating mnemonicSeed'));
        return;
      }

      // if seed exists - this will error with Seed Exists, but we ignore it
      // else we create the seed
      await walletSensRepository.newSeed(seed: seed!);

      if (state.passPhrase.isNotEmpty) {
        final passPhrase = state.passPhrase.isEmpty ? '' : state.passPhrase;

        final passphrase =
            Passphrase(passphrase: passPhrase, sourceFingerprint: selectedWallet.sourceFingerprint);

        final err = await walletSensRepository.newPassphrase(
          passphrase: passphrase,
          seedFingerprintIndex: seed.getSeedStorageString(),
        );

        if (err != null) {
          emit(
            state.copyWith(
              errSavingWallet: err.toString(),
              savingWallet: false,
            ),
          );
          return;
        }
      }
    }

    final err = await walletsStorageRepository.newWallet(
      selectedWallet,
    );

    if (err != null) {
      emit(
        state.copyWith(
          errSavingWallet: err.toString(),
          savingWallet: false,
        ),
      );
    } else {
      emit(
        state.copyWith(
          savingWallet: false,
          savedWallet: (state.walletLabel != null && state.walletLabel != '')
              ? selectedWallet.copyWith(name: state.walletLabel)
              : selectedWallet,
        ),
      );
    }
    reset();
  }

  void reset() async {
    emit(
      state.copyWith(
        words12: [...emptyWords12],
        words24: [...emptyWords24],
        passPhrase: '',
        xpub: '',
        tempXpub: '',
        fingerprint: '',
        customDerivation: '',
        manualPublicDescriptor: '',
        manualPublicChangeDescriptor: '',
        manualCombinedPublicDescriptor: '',
        coldCard: null,
      ),
    );
  }

  void clearErrors() async {
    emit(
      state.copyWith(
        errImporting: '',
        errLoadingFile: '',
        errSavingWallet: '',
      ),
    );
  }
}
