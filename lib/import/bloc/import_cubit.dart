import 'dart:convert';

import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/nfc.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bb_mobile/import/bloc/import_state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportWalletCubit extends Cubit<ImportState> {
  ImportWalletCubit({
    required this.barcode,
    required this.filePicker,
    required this.nfc,
    required this.settingsCubit,
    required this.walletCreate,
    required this.storage,
    required this.secureStorage,
    required this.walletUpdate,
  }) : super(
          const ImportState(
              // words: [
              //   ...r2,
              // ],
              ),
        );

  final Barcode barcode;
  final FilePick filePicker;
  final NFCPicker nfc;

  final SettingsCubit settingsCubit;
  final WalletCreate walletCreate;
  final IStorage storage;
  final IStorage secureStorage;
  final WalletUpdate walletUpdate;

  void backClicked() {
    switch (state.importStep) {
      case ImportSteps.importWords:
      case ImportSteps.selectImportType:
      case ImportSteps.importXpub:
        emit(
          state.copyWith(
            importStep: ImportSteps.selectCreateType,
            importType: ImportTypes.notSelected,
            // words: [for (int i = 0; i < 12; i++) ''],
          ),
        );

      case ImportSteps.scanningNFC:
      case ImportSteps.scanningWallets:
      case ImportSteps.selectWalletFormat:
        if (state.importType == ImportTypes.xpub)
          emit(
            state.copyWith(
              importStep: ImportSteps.importXpub,
              importType: state.importType,
            ),
          );
        else if (state.importType == ImportTypes.words)
          emit(
            state.copyWith(
              importStep: ImportSteps.importWords,
              importType: state.importType,
              words: [for (int i = 0; i < 12; i++) ''],
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
        importStep: ImportSteps.importWords,
        importType: ImportTypes.words,
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

  void wordChanged(int idx, String text) {
    final words = state.words.toList();
    words[idx] = text;
    emit(state.copyWith(words: words));
  }

  void passwordChanged(String text) {
    emit(state.copyWith(password: text));
  }

  void xpubChanged(String text) {
    emit(state.copyWith(xpub: text));
  }

  void descriptorChanged(String text) {
    emit(state.copyWith(manualDescriptor: text));
  }

  void cDescriptorChanged(String text) {
    emit(state.copyWith(manualChangeDescriptor: text));
  }

  void combinedDescriptorChanged(String text) {
    emit(state.copyWith(manualCombinedDescriptor: text));

    final desc = splitCombinedChanged(text, false);
    final cdesc = splitCombinedChanged(text, true);

    emit(state.copyWith(manualDescriptor: desc, manualChangeDescriptor: cdesc));
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
    emit(state.copyWith(errImporting: ''));
    if (state.xpub.isEmpty) {
      emit(state.copyWith(errImporting: 'Please enter xpub'));
      return;
    }

    emit(
      state.copyWith(
        tempXpub: state.xpub,
        xpub: convertToXpubStr(state.xpub),
        importType: ImportTypes.xpub,
      ),
    );

    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) return;

    emit(state.copyWith(importStep: ImportSteps.scanningWallets));
  }

  void recoverWalletClicked() async {
    emit(state.copyWith(importType: ImportTypes.words, errImporting: ''));
    for (final word in state.words)
      if (word.isEmpty) {
        emit(state.copyWith(errImporting: 'Please fill all words'));
        return;
      }
    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) return;

    emit(state.copyWith(importStep: ImportSteps.scanningWallets));
  }

  Future _updateWalletDetailsForSelection() async {
    try {
      final isTesnet = settingsCubit.state.testnet;
      final type = state.importType;

      final wallets = <Wallet>[];

      switch (type) {
        case ImportTypes.words:
          final mne = state.words.join(' ');
          final password = state.password.isEmpty ? null : state.password;
          final path = state.customDerivation.isEmpty ? null : state.customDerivation;

          final (fingerPrint, errr) = await walletCreate.getMneFingerprint(
            mne: mne,
            isTestnet: isTesnet,
            walletPurpose: WalletPurpose.bip84,
          );
          if (errr != null) throw errr;

          final (w, err) = Wallet.fromMnemonicAll(
            mne: mne,
            password: password,
            path: path,
            isTestNet: isTesnet,
            bbWalletType: BBWalletType.words,
            fngr: fingerPrint!,
          );

          if (err != null) throw err;
          wallets.addAll(w!);

        case ImportTypes.xpub:
          if (state.manualChangeDescriptor != null &&
              state.manualDescriptor != null &&
              state.manualChangeDescriptor!.isNotEmpty &&
              state.manualDescriptor!.isNotEmpty) {
            var fngr = fingerPrintFromDescr(
              state.manualChangeDescriptor!,
              isTesnet: isTesnet,
            );

            final noFngr = fngr.isEmpty;
            if (noFngr) fngr = generateFingerPrint(6);

            final (w, err) = Wallet.fromDescrAll(
              changeDescriptor: state.manualChangeDescriptor!,
              descriptor: state.manualDescriptor!,
              isTestNet: isTesnet,
              bbWalletType: BBWalletType.descriptors,
              fngr: fngr,
            );

            if (err != null) throw err;

            wallets.addAll(w!);
          } else if (state.fingerprint.isEmpty) {
            final randFngr = generateFingerPrint(3);

            final (w, err) = Wallet.fromXpubNoPathAll(
              xpub: state.xpub,
              isTestNet: isTesnet,
              bbWalletType: BBWalletType.descriptors,
              fngr: 'watcher#' + randFngr,
            );

            if (err != null) throw err;
            wallets.addAll(w!);
          } else {
            final path = state.customDerivation;
            final fingerprint = state.fingerprint;

            final (w, err) = Wallet.fromXpubWithPathAll(
              xpub: state.xpub,
              isTestNet: isTesnet,
              bbWalletType: BBWalletType.xpub,
              fngr: fingerprint,
              path: path,
            );

            if (err != null) throw err;
            wallets.addAll(w!);
          }

        case ImportTypes.coldcard:
          final coldcard = state.coldCard!;

          final (w, err) = Wallet.fromColdCardAll(
            coldCard: coldcard,
            isTestNet: isTesnet,
          );

          if (err != null) throw err;
          wallets.addAll(w!);

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

  void walletPurposeChanged(WalletPurpose purpose) {
    emit(state.copyWith(walletPurpose: purpose));
  }

  void saveClicked() async {
    emit(state.copyWith(savingWallet: true, errSavingWallet: ''));
    final selectedWallet = state.getSelectWalletDetails();

    final err = await walletUpdate.addWalletToList(
      wallet: selectedWallet!,
      storage: storage,
      secureStorage: secureStorage,
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

    emit(
      state.copyWith(
        savingWallet: false,
        savedWallet: selectedWallet,
      ),
    );
  }
}
