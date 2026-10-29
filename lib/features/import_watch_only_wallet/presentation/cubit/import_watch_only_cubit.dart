import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/validate_watch_only_import_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class ImportWatchOnlyCubit extends Cubit<ImportWatchOnlyState> {
  final ImportWatchOnlyDescriptorUsecase _importWatchOnlyDescriptorUsecase;
  final ImportWatchOnlyXpubUsecase _importWatchOnlyXpubUsecase;
  final ParseWatchOnlyInputUsecase _parseWatchOnlyInputUsecase;
  final ValidateWatchOnlyImportUsecase _validateImport;
  int _selectionGeneration = 0;

  ImportWatchOnlyCubit({
    WatchOnlyWalletEntity? watchOnlyWallet,
    required this._importWatchOnlyDescriptorUsecase,
    required this._importWatchOnlyXpubUsecase,
    required this._parseWatchOnlyInputUsecase,
    required this._validateImport,
  }) : super(ImportWatchOnlyState(watchOnlyWallet: watchOnlyWallet));

  void init() {
    if (state.watchOnlyWallet != null) {
      emit(state.copyWith(watchOnlyWallet: state.watchOnlyWallet));
    }
  }

  void updateLabel(String label) {
    final selected = state.watchOnlyWallet;
    if (selected == null) return;
    _selectionGeneration++;
    final watchOnlyWallet = selected.copyWith(label: label);
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet, failure: null));
  }

  Future<WatchOnlyWalletEntity?> _validatedWallet() async {
    emit(state.copyWith(failure: null));
    final generation = _selectionGeneration;
    final result = await _validateImport.execute(state.watchOnlyWallet);
    if (isClosed || generation != _selectionGeneration) return null;
    switch (result) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return null;
    }
  }

  Future<bool> validateImport() async => await _validatedWallet() != null;

  Future<void> import({
    WalletBirthday? birthday,
    BitcoinSyncSource bitcoinSyncSource = BitcoinSyncSource.electrum,
  }) async {
    final generation = _selectionGeneration;
    final wallet = await _validatedWallet();
    if (wallet == null) return;

    final Result<Wallet, ImportWatchOnlyFailure> result;
    if (wallet is WatchOnlyDescriptorEntity) {
      result = await _importWatchOnlyDescriptorUsecase.execute(
        watchOnlyDescriptor: wallet,
        birthday: birthday,
        bitcoinSyncSource: bitcoinSyncSource,
      );
    } else if (wallet is WatchOnlyXpubEntity) {
      result = await _importWatchOnlyXpubUsecase.execute(
        watchOnlyXpub: wallet,
        birthday: birthday,
        bitcoinSyncSource: bitcoinSyncSource,
      );
    } else {
      return;
    }

    if (isClosed || generation != _selectionGeneration) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(importedWallet: value));
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> parsePastedInput(String input) async {
    final generation = ++_selectionGeneration;
    final trimmed = input.trim();
    emit(state.copyWith(input: trimmed, watchOnlyWallet: null, failure: null));
    if (trimmed.length >= 111) {
      final parsed = await _parseWatchOnlyInputUsecase.execute(trimmed);
      if (isClosed || generation != _selectionGeneration) return;
      switch (parsed) {
        case Ok(:final value):
          emit(state.copyWith(watchOnlyWallet: value));
        case Err(:final failure):
          emit(state.copyWith(failure: failure));
      }
    }
  }

  void onSignerChanged(SignerEntity? value) {
    final selected = state.watchOnlyWallet;
    if (value == null || selected == null) return;
    _selectionGeneration++;
    final watchOnlyWallet = selected.copyWith(signer: value);
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet, failure: null));
  }

  void onSignerDeviceChanged(SignerDeviceEntity? device) {
    final entity = state.watchOnlyWallet;
    if (entity is! WatchOnlyDescriptorEntity) return;
    _selectionGeneration++;

    final watchOnlyWallet = entity.copyWith(
      signerDevice: device,
      signer: device == null ? SignerEntity.none : SignerEntity.remote,
    );
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet, failure: null));
  }

  void onDerivationChanged(satoshifier.Derivation? value) {
    final entity = state.watchOnlyWallet;
    if (entity is! WatchOnlyXpubEntity || value == null) return;
    final newPubkey = switch (value) {
      satoshifier.Derivation.bip84 => satoshifier.Bip32Utils.convertToZpub(
        entity.extendedPubkey.pubkey,
      ),
      satoshifier.Derivation.bip49 => satoshifier.Bip32Utils.convertToYpub(
        entity.extendedPubkey.pubkey,
      ),
      satoshifier.Derivation.bip44 => satoshifier.Bip32Utils.convertToXpub(
        entity.extendedPubkey.pubkey,
      ),
    };

    parsePastedInput(newPubkey);
  }
}
