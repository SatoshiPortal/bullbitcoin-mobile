import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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

  ImportWatchOnlyCubit({
    WatchOnlyWalletEntity? watchOnlyWallet,
    required this._importWatchOnlyDescriptorUsecase,
    required this._importWatchOnlyXpubUsecase,
    required this._parseWatchOnlyInputUsecase,
  }) : super(ImportWatchOnlyState(watchOnlyWallet: watchOnlyWallet));

  void init() {
    if (state.watchOnlyWallet != null) {
      emit(state.copyWith(watchOnlyWallet: state.watchOnlyWallet));
    }
  }

  void updateLabel(String label) {
    if (state.watchOnlyWallet == null) return;
    final watchOnlyWallet = state.watchOnlyWallet!.copyWith(label: label);
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet));
  }

  Future<void> import() async {
    emit(state.copyWith(failure: null));

    final wallet = state.watchOnlyWallet;
    if (wallet == null) {
      emit(state.copyWith(failure: const NoWalletSelectedFailure()));
      return;
    }
    if (wallet.label.isEmpty) {
      emit(state.copyWith(failure: const LabelRequiredFailure()));
      return;
    }

    final Result<Wallet, ImportWatchOnlyFailure> result;
    if (wallet is WatchOnlyDescriptorEntity) {
      result = await _importWatchOnlyDescriptorUsecase.execute(
        watchOnlyDescriptor: wallet,
      );
    } else if (wallet is WatchOnlyXpubEntity) {
      result = await _importWatchOnlyXpubUsecase.execute(watchOnlyXpub: wallet);
    } else {
      return;
    }

    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(importedWallet: value));
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> parsePastedInput(String input) async {
    final trimmed = input.trim();
    emit(state.copyWith(input: trimmed));
    if (trimmed.length >= 111) {
      switch (await _parseWatchOnlyInputUsecase.execute(trimmed)) {
        case Ok(:final value):
          emit(state.copyWith(watchOnlyWallet: value));
        case Err(:final failure):
          emit(state.copyWith(failure: failure));
      }
    }
  }

  void onSignerChanged(SignerEntity? value) {
    if (value == null) return;
    final watchOnlyWallet = state.watchOnlyWallet!.copyWith(signer: value);
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet));
  }

  void onSignerDeviceChanged(SignerDeviceEntity? device) {
    if (state.watchOnlyWallet == null) return;
    if (state.watchOnlyWallet is! WatchOnlyDescriptorEntity) return;

    final entity = state.watchOnlyWallet! as WatchOnlyDescriptorEntity;

    final watchOnlyWallet = entity.copyWith(
      signerDevice: device,
      signer: device == null ? SignerEntity.none : SignerEntity.remote,
    );
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet));
  }

  void onDerivationChanged(satoshifier.Derivation? value) {
    if (state.watchOnlyWallet == null) return;
    if (state.watchOnlyWallet is! WatchOnlyXpubEntity) return;
    if (value == null) return;

    final entity = state.watchOnlyWallet! as WatchOnlyXpubEntity;
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
