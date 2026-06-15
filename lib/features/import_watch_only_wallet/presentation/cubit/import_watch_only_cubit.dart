import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_error.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class ImportWatchOnlyCubit extends Cubit<ImportWatchOnlyState> {
  final ImportWatchOnlyDescriptorUsecase _importWatchOnlyDescriptorUsecase;
  final ImportWatchOnlyXpubUsecase _importWatchOnlyXpubUsecase;

  ImportWatchOnlyCubit({
    WatchOnlyWalletEntity? watchOnlyWallet,
    required this._importWatchOnlyDescriptorUsecase,
    required this._importWatchOnlyXpubUsecase,
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
    emit(state.copyWith(error: null));

    final wallet = state.watchOnlyWallet;
    if (wallet == null) {
      emit(state.copyWith(error: const NoWalletSelectedError()));
      return;
    }
    if (wallet.label.isEmpty) {
      emit(state.copyWith(error: const LabelRequiredError()));
      return;
    }

    try {
      final Wallet importedWallet;
      if (wallet is WatchOnlyDescriptorEntity) {
        importedWallet = await _importWatchOnlyDescriptorUsecase.execute(
          watchOnlyDescriptor: wallet,
        );
      } else if (wallet is WatchOnlyXpubEntity) {
        importedWallet = await _importWatchOnlyXpubUsecase.execute(
          watchOnlyXpub: wallet,
        );
      } else {
        return;
      }
      emit(state.copyWith(importedWallet: importedWallet));
    } on ImportWatchOnlyError catch (e) {
      emit(state.copyWith(error: e));
    } catch (e, st) {
      // Unforeseen failure — keep the raw detail in the logs (Sentry) and show
      // a generic localized message via the unexpected variant.
      log.severe(
        message: 'Unexpected watch-only import failure',
        error: e,
        trace: st,
      );
      emit(state.copyWith(error: UnexpectedImportError(e.toString())));
    }
  }

  Future<void> parsePastedInput(String input) async {
    final value = input.trim();
    emit(state.copyWith(input: value));
    if (value.length >= 111) {
      try {
        final entity = await WatchOnlyWalletEntity.parse(value);
        emit(state.copyWith(watchOnlyWallet: entity));
      } catch (e, st) {
        log.warning('Failed to parse watch-only input', error: e, trace: st);
        emit(state.copyWith(error: const InvalidFormatError()));
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
