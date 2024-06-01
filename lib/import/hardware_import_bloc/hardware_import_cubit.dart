import 'dart:convert';

import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/create.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/import/hardware_import_bloc/hardware_import_state.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HardwareImportCubit extends Cubit<HardwareImportState> {
  HardwareImportCubit({
    required Barcode barcode,
    required WalletCreate walletCreate,
    required WalletSensitiveCreate walletSensCreate,
    required WalletsStorageRepository walletsStorageRepository,
    required WalletSensitiveStorageRepository walletSensRepository,
    required NetworkCubit networkCubit,
    required BDKCreate bdkCreate,
    required FilePick filePicker,
    required BDKSensitiveCreate bdkSensitiveCreate,
  })  : _barcode = barcode,
        _walletCreate = walletCreate,
        _walletSensRepository = walletSensRepository,
        _walletsStorageRepository = walletsStorageRepository,
        _walletSensCreate = walletSensCreate,
        _networkCubit = networkCubit,
        _bdkCreate = bdkCreate,
        _filePicker = filePicker,
        _bdkSensitiveCreate = bdkSensitiveCreate,
        super(const HardwareImportState());

  final Barcode _barcode;
  final FilePick _filePicker;

  final WalletCreate _walletCreate;
  final BDKCreate _bdkCreate;
  final BDKSensitiveCreate _bdkSensitiveCreate;
  final WalletSensitiveCreate _walletSensCreate;

  final WalletsStorageRepository _walletsStorageRepository;
  final WalletSensitiveStorageRepository _walletSensRepository;
  final NetworkCubit _networkCubit;

  void reset() => emit(const HardwareImportState());

  void updateSelectScriptType(ScriptType selectScriptType) =>
      emit(state.copyWith(selectScriptType: selectScriptType));

  void updateLabel(String label) => emit(state.copyWith(label: label));

  void updateInputText(String inputText) {
    emit(state.copyWith(inputText: inputText));
    _processInput();
  }

  void scanQRClicked() async {
    final (res, err) = await _barcode.scan();
    if (err != null) {
      emit(state.copyWith(errScanningInput: err.toString()));
      return;
    }

    emit(state.copyWith(inputText: res!));
    _processInput();
  }

  void selectFile() async {
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
    final coldCard = _parseCC(state.inputText);
    if (coldCard != null) {
      _processColdCard(coldCard);
      return;
    }

    _processXpub(state.inputText);
  }

  ColdCard? _parseCC(String input) {
    try {
      final ccObj = jsonDecode(input) as Map<String, dynamic>;
      final coldcard = ColdCard.fromJson(ccObj);
      return coldcard;
    } catch (e) {
      return null;
    }
  }

  Future checkWalletLabel() async {
    final label = state.label;
    if (label.isEmpty)
      emit(state.copyWith(errLabel: 'Wallet Label is required'));
    else if (label.length < 3)
      emit(
        state.copyWith(
          errLabel: 'Wallet Label must be at least 3 characters',
        ),
      );
    else if (label.length > 20)
      emit(
        state.copyWith(
          errLabel: 'Wallet Label must be less than 20 characters',
        ),
      );
    else
      emit(state.copyWith(errLabel: ''));
  }

  void _processColdCard(ColdCard coldCard) async {
    final wallets = <Wallet>[];

    final network = _networkCubit.state.getBBNetwork();

    final (cws, wErrs) = await _bdkCreate.allFromColdCard(
      coldCard,
      network,
    );
    if (wErrs != null) {
      emit(
        state.copyWith(
          errScanningInput: 'Error creating Wallets from ColdCard',
          scanningInput: false,
        ),
      );
      return;
    }
    wallets.addAll(cws!);

    emit(
      state.copyWith(
        walletDetails: wallets,
        scanningInput: false,
      ),
    );
  }

  void _processXpub(String xpub) async {
    final wallets = <Wallet>[];

    if (xpub.contains('[')) {
      // has origin info
      final (wxpub, wErrs) = await _bdkCreate.oneFromXpubWithOrigin(
        xpub,
      );
      if (wErrs != null) {
        emit(
          state.copyWith(
            errScanningInput: 'Error creating Wallets from Xpub',
            scanningInput: false,
          ),
        );
        return;
      }
      updateSelectScriptType(wxpub!.scriptType);
      wallets.addAll([wxpub]);
    } else {
      final (wxpub, wErrs) = await _bdkCreate.oneFromSlip132Pub(
        xpub,
      );
      if (wErrs != null) {
        emit(
          state.copyWith(
            errScanningInput: 'Error creating Wallets from Xpub',
            scanningInput: false,
          ),
        );
        return;
      }
      updateSelectScriptType(wxpub!.scriptType);
      wallets.addAll([wxpub]);
    }

    emit(
      state.copyWith(
        walletDetails: wallets,
        scanningInput: false,
      ),
    );
  }

  void saveClicked() async {
    await checkWalletLabel();
    if (state.errLabel.isNotEmpty) return;

    // final network = _networkCubit.state.getBBNetwork();

    Wallet? selectedWallet = state.getSelectWalletDetails();
    if (selectedWallet == null) return;
    selectedWallet = (state.label.isEmpty)
        ? selectedWallet.copyWith(name: state.label)
        : selectedWallet;

    // var walletLabel = state.label ?? '';
    final secureWallet = selectedWallet;

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

    await Future.delayed(const Duration(seconds: 1));

    emit(
      state.copyWith(
        savingWallet: false,
        savedWallet: true,
      ),
    );
  }
}
