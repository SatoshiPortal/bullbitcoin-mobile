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
import 'package:bb_mobile/_pkg/wallet/lwk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/testable_wallets.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bb_mobile/import/bloc/import_state.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportWalletCubit extends Cubit<ImportState> {
  ImportWalletCubit({
    required Barcode barcode,
    required FilePick filePicker,
    required NFCPicker nfc,
    required WalletCreate walletCreate,
    required WalletSensitiveCreate walletSensCreate,
    required WalletsStorageRepository walletsStorageRepository,
    required WalletSensitiveStorageRepository walletSensRepository,
    required NetworkCubit networkCubit,
    required BDKCreate bdkCreate,
    required BDKSensitiveCreate bdkSensitiveCreate,
    required LWKSensitiveCreate lwkSensitiveCreate,
    bool mainWallet = false,
    bool useTestWallet = false,
  })  : _networkCubit = networkCubit,
        _walletSensRepository = walletSensRepository,
        _walletsStorageRepository = walletsStorageRepository,
        _walletSensCreate = walletSensCreate,
        _lwkSensitiveCreate = lwkSensitiveCreate,
        _bdkSensitiveCreate = bdkSensitiveCreate,
        _bdkCreate = bdkCreate,
        _walletCreate = walletCreate,
        _nfc = nfc,
        _filePicker = filePicker,
        _barcode = barcode,
        super(ImportState(mainWallet: mainWallet)) {
    if (useTestWallet)
      emit(state.copyWith(words12: [...importW(instantTN1)]));
    else
      reset();

    if (mainWallet) recoverClicked();
  }

  final Barcode _barcode;
  final FilePick _filePicker;
  final NFCPicker _nfc;

  final WalletCreate _walletCreate;
  final BDKCreate _bdkCreate;
  final BDKSensitiveCreate _bdkSensitiveCreate;
  final LWKSensitiveCreate _lwkSensitiveCreate;
  final WalletSensitiveCreate _walletSensCreate;

  final WalletsStorageRepository _walletsStorageRepository;
  final WalletSensitiveStorageRepository _walletSensRepository;
  final NetworkCubit _networkCubit;

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
    final (res, err) = await _barcode.scan();
    if (err != null) {
      emit(
        state.copyWith(
          errImporting: err.toString(),
          loadingFile: false,
        ),
      );
      return;
    }

    if (state.importStep == ImportSteps.importXpub)
      emit(state.copyWith(xpub: res!));

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

    final err = await _nfc.startSession(coldCardNFCReceived);
    if (err != null) {
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: err.toString(),
          loadingFile: false,
        ),
      );

      final errStopping = _nfc.stopSession();
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
    final err = _nfc.stopSession();
    if (err != null) emit(state.copyWith(errLoadingFile: err.toString()));
    emit(state.copyWith(loadingFile: false));
  }

  void coldCardNFCReceived(String jsnStr) async {
    final ccObj = jsonDecode(jsnStr) as Map<String, dynamic>;
    final coldcard = ColdCard.fromJson(ccObj);

    emit(state.copyWith(coldCard: coldcard, importType: ImportTypes.coldcard));

    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) {
      final errStoppping = _nfc.stopSession();
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
    final (file, err) = await _filePicker.pickFile();
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
    if (!state.mainWallet) await checkWalletLabel();
    if (state.errSavingWallet.isNotEmpty) return;

    final words =
        state.importType == ImportTypes.words12 ? state.words12 : state.words24;

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
      final network =
          _networkCubit.state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet;

      switch (type) {
        case ImportTypes.words12:
          final mnemonic = state.words12.map((_) => _.word).join(' ');
          final passphrase = state.passPhrase.isEmpty ? '' : state.passPhrase;
          final (ws, wErrs) = await _bdkSensitiveCreate.allFromBIP39(
            mnemonic: mnemonic,
            passphrase: passphrase,
            network: network,
            isImported: true,
            walletCreate: _walletCreate,
          );
          if (wErrs != null) {
            emit(
              state.copyWith(
                errImporting: 'Error creating Wallets from Bip 39',
              ),
            );
            return;
          }
          wallets.addAll(ws!);
        case ImportTypes.words24:
          final mnemonic = state.words24.map((_) => _.word).join(' ');
          final passphrase = state.passPhrase.isEmpty ? '' : state.passPhrase;

          final (ws, wErrs) = await _bdkSensitiveCreate.allFromBIP39(
            mnemonic: mnemonic,
            passphrase: passphrase,
            network: network,
            isImported: true,
            walletCreate: _walletCreate,
          );
          if (wErrs != null) {
            emit(
              state.copyWith(
                errImporting: 'Error creating Wallets from Bip 39',
              ),
            );
            return;
          }
          wallets.addAll(ws!);

        case ImportTypes.xpub:
          if (state.xpub.contains('[')) {
            // has origin info
            final (wxpub, wErrs) = await _bdkCreate.oneFromXpubWithOrigin(
              state.xpub,
            );
            if (wErrs != null) {
              emit(
                state.copyWith(
                  errImporting: 'Error creating Wallets from Xpub',
                ),
              );
              return;
            }
            scriptTypeChanged(wxpub!.scriptType);
            wallets.addAll([wxpub]);
          } else {
            final (wxpub, wErrs) = await _bdkCreate.oneFromSlip132Pub(
              state.xpub,
            );
            if (wErrs != null) {
              emit(
                state.copyWith(
                  errImporting: 'Error creating Wallets from Xpub',
                ),
              );
              return;
            }
            scriptTypeChanged(wxpub!.scriptType);
            wallets.addAll([wxpub]);
          }
        case ImportTypes.coldcard:
          final coldcard = state.coldCard!;

          final (cws, wErrs) = await _bdkCreate.allFromColdCard(
            coldcard,
            network,
          );
          if (wErrs != null) {
            emit(
              state.copyWith(
                errImporting: 'Error creating Wallets from ColdCard',
              ),
            );
            return;
          }
          wallets.addAll(cws!);

        default:
          break;
      }

      if (wallets.isEmpty) throw 'Unable to create a wallet';
      if (state.mainWallet)
        wallets.removeWhere((_) => _.scriptType != ScriptType.bip84);

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
      emit(
        state.copyWith(
          errSavingWallet: 'Wallet Label must be at least 3 characters',
        ),
      );
    else if (label.length > 20)
      emit(
        state.copyWith(
          errSavingWallet: 'Wallet Label must be less than 20 characters',
        ),
      );
    else
      emit(state.copyWith(errSavingWallet: ''));
  }

  void saveClicked() async {
    emit(state.copyWith(savingWallet: true, errSavingWallet: ''));

    Wallet? selectedWallet = state.getSelectWalletDetails();
    if (selectedWallet == null) return;
    selectedWallet = (state.walletLabel != null && state.walletLabel != '')
        ? selectedWallet.copyWith(name: state.walletLabel)
        : selectedWallet;

    final network =
        _networkCubit.state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet;

    if (selectedWallet.type == BBWalletType.words) {
      final mnemonic = (state.importType == ImportTypes.words12)
          ? state.words12.map((_) => _.word).join(' ')
          : state.words24.map((_) => _.word).join(' ');
      final (seed, sErr) =
          await _walletSensCreate.mnemonicSeed(mnemonic, network);
      if (sErr != null) {
        emit(state.copyWith(errImporting: 'Error creating mnemonicSeed'));
        return;
      }

      // if seed exists - this will error with Seed Exists, but we ignore it
      // else we create the seed
      await _walletSensRepository.newSeed(seed: seed!);

      if (state.passPhrase.isNotEmpty) {
        final passPhrase = state.passPhrase.isEmpty ? '' : state.passPhrase;

        final passphrase = Passphrase(
          passphrase: passPhrase,
          sourceFingerprint: selectedWallet.sourceFingerprint,
        );

        final err = await _walletSensRepository.newPassphrase(
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

      if (state.mainWallet)
        await _createLiquid(
          seed: seed,
          passPhrase: state.passPhrase,
          network: network,
        );
    }

    if (state.mainWallet)
      selectedWallet = selectedWallet.copyWith(mainWallet: true);
    var walletLabel = state.walletLabel ?? '';
    if (state.mainWallet) walletLabel = selectedWallet.creationName();
    final secureWallet = selectedWallet.copyWith(name: walletLabel);

    final err = await _walletsStorageRepository.newWallet(
      secureWallet,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errSavingWallet: err.toString(),
          savingWallet: false,
        ),
      );
      reset();
      return;
    }

    emit(
      state.copyWith(
        savingWallet: false,
        savedWallet: true,
      ),
    );

    await Future.delayed(const Duration(seconds: 1));

    reset();
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
      walletType: BBWalletType.instant,
      walletCreate: _walletCreate,
      // walletType: network,
      // false,
    );
    if (wErr != null) {
      emit(
        state.copyWith(
          savingWallet: false,
          errSavingWallet: 'Error Creating Wallet',
        ),
      );
      return null;
    }

    wallet = wallet!.copyWith(backupTested: true);
    if (state.mainWallet) wallet = wallet.copyWith(mainWallet: true);

    var walletLabel = state.walletLabel ?? '';
    if (state.mainWallet) walletLabel = wallet.creationName();
    final updatedWallet = wallet.copyWith(name: walletLabel);

    final wsErr = await _walletsStorageRepository.newWallet(updatedWallet);
    if (wsErr != null) {
      emit(
        state.copyWith(
          savingWallet: false,
          errSavingWallet: 'Error Saving Wallet',
        ),
      );
    }

    return updatedWallet;
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
        savedWallet: false,
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
