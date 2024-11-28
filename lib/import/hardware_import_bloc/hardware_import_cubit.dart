import 'dart:convert';
import 'dart:developer';

import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/testable_wallets.dart';
import 'package:bb_mobile/import/hardware_import_bloc/hardware_import_state.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HardwareImportCubit extends Cubit<HardwareImportState> {
  HardwareImportCubit({
    required Barcode barcode,
    required WalletsStorageRepository walletsStorageRepository,
    required NetworkCubit networkCubit,
    required BDKCreate bdkCreate,
    required FilePick filePicker,
  })  : _barcode = barcode,
        _walletsStorageRepository = walletsStorageRepository,
        _networkCubit = networkCubit,
        _bdkCreate = bdkCreate,
        _filePicker = filePicker,
        super(const HardwareImportState()) {
    log(jsonEncode(cc2));
  }

  final Barcode _barcode;
  final FilePick _filePicker;

  final BDKCreate _bdkCreate;

  final WalletsStorageRepository _walletsStorageRepository;
  final NetworkCubit _networkCubit;

  void reset() => emit(const HardwareImportState());

  void updateSelectScriptType(ScriptType selectScriptType) =>
      emit(state.copyWith(selectScriptType: selectScriptType));

  void updateLabel(String label) => emit(state.copyWith(label: label));

  void updateInputText(String inputText) {
    emit(state.copyWith(inputText: inputText));
    _processInput();
  }

  Future<void> scanQRClicked() async {
    final (res, err) = await _barcode.scan();
    if (err != null) {
      emit(state.copyWith(errScanningInput: err.toString()));
      return;
    }

    emit(state.copyWith(inputText: res!));
    _processInput();
  }

  Future<void> selectFile() async {
    final (file, err) = await _filePicker.pickFile();
    if (err != null) {
      emit(state.copyWith(errScanningInput: err.toString()));
      return;
    }

    emit(state.copyWith(inputText: file!));
    _processInput();
  }

  void _processInput() {
    emit(state.copyWith(scanningInput: true));
    if (state.inputText.isEmpty) return;
    final coldCard = state.parseCC(state.inputText);
    if (coldCard != null) {
      _processColdCard(coldCard);
      return;
    }

    _processXpub(state.inputText);
  }

  Future checkWalletLabel() async {
    final label = state.label;
    if (label.isEmpty) {
      emit(state.copyWith(errLabel: 'Wallet Label is required'));
    } else if (label.length < 3) {
      emit(
        state.copyWith(
          errLabel: 'Wallet Label must be at least 3 characters',
        ),
      );
    } else if (label.length > 20) {
      emit(
        state.copyWith(
          errLabel: 'Wallet Label must be less than 20 characters',
        ),
      );
    } else {
      emit(state.copyWith(errLabel: ''));
    }
  }

  Future<void> _processColdCard(ColdCard coldCard) async {
    final wallets = <Wallet>[];

    final network = _networkCubit.state.getBBNetwork();

    final (cws, err) = await _bdkCreate.allFromColdCard(
      coldCard,
      network,
      checkFirstAddress: false,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errScanningInput: err.toString(),
          scanningInput: false,
        ),
      );
      return;
    }
    wallets.addAll(cws!);

    emit(
      state.copyWith(
        coldCardDetected: true,
        tempColdCard: coldCard,
        walletDetails: wallets,
        scanningInput: false,
      ),
    );
  }

  Future<void> _processXpub(String xpub) async {
    final wallets = <Wallet>[];

    if (xpub.contains('[')) {
      // has origin info
      final (wxpub, err) = await _bdkCreate.oneFromXpubWithOrigin(
        xpub,
      );
      if (err != null) {
        emit(
          state.copyWith(
            errScanningInput: err.toString(),
            scanningInput: false,
          ),
        );
        return;
      }
      updateSelectScriptType(wxpub!.scriptType);
      wallets.addAll([wxpub]);
    } else {
      if (xpub.startsWith('ypub') || xpub.startsWith('zpub')) {
        final (wxpub, err) = await _bdkCreate.oneFromSlip132Pub(
          xpub,
        );
        if (err != null) {
          emit(
            state.copyWith(
              errScanningInput: err.toString(),
              scanningInput: false,
            ),
          );
          return;
        }
        updateSelectScriptType(wxpub!.scriptType);
        wallets.addAll([wxpub]);
      } else {
        final (wxpub, err) = await _bdkCreate.allFromMasterXpub(
          xpub,
        );
        if (err != null) {
          emit(
            state.copyWith(
              errScanningInput: err.toString(),
              scanningInput: false,
            ),
          );
          return;
        }
        updateSelectScriptType(wxpub!.first.scriptType);
        wallets.addAll(wxpub);
      }
    }

    emit(
      state.copyWith(
        walletDetails: wallets,
        scanningInput: false,
      ),
    );
  }

  Future<void> saveClicked() async {
    await checkWalletLabel();
    if (state.errLabel.isNotEmpty) return;

    // final network = _networkCubit.state.getBBNetwork();

    final selectedWallet = state.getSelectWalletDetails();
    if (selectedWallet == null) return;

    final secureWallet = selectedWallet.copyWith(name: state.label);

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
      return;
    }

    // await Future.delayed(const Duration(seconds: 1));

    emit(
      state.copyWith(
        savingWallet: false,
        savedWallet: true,
      ),
    );
  }
}
