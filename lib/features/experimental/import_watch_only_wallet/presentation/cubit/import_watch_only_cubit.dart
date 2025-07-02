import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/import_watch_only_usecase.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:convert/convert.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportWatchOnlyCubit extends Cubit<ImportWatchOnlyState> {
  final ImportWatchOnlyUsecase _importWatchOnlyUsecase;

  ImportWatchOnlyCubit({
    WatchOnlyWalletEntity? watchOnlyWallet,
    required ImportWatchOnlyUsecase importWatchOnlyUsecase,
  }) : _importWatchOnlyUsecase = importWatchOnlyUsecase,
       super(ImportWatchOnlyState(watchOnlyWallet: watchOnlyWallet));

  void init() {
    if (state.watchOnlyWallet != null) {
      final combinedDescriptor = state.watchOnlyWallet!.descriptor.combined;
      parsePastedInput(combinedDescriptor);
    }
  }

  void updateLabel(String label) {
    if (state.watchOnlyWallet == null) return;
    final watchOnlyWallet = state.watchOnlyWallet!.copyWith(label: label);
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet));
  }

  void overrideMasterFingerprint(String fingerprint) {
    if (fingerprint.isNotEmpty && fingerprint.length == 8) {
      try {
        hex.decode(fingerprint);
        final walletWithNewMasterFingerprint = state.watchOnlyWallet!.copyWith(
          masterFingerprint: fingerprint,
        );
        emit(
          state.copyWith(
            error: '',
            overrideMasterFingerprint: fingerprint,
            watchOnlyWallet: walletWithNewMasterFingerprint,
          ),
        );
      } catch (e) {
        emit(state.copyWith(error: 'fingerprint must be a valid hex string'));
        return;
      }
    } else {
      emit(state.copyWith(error: '', overrideMasterFingerprint: fingerprint));
      return;
    }
  }

  Future<void> import() async {
    if (state.watchOnlyWallet == null) return;

    try {
      final wallet = await _importWatchOnlyUsecase(
        watchOnly: state.watchOnlyWallet!.watchOnly,
        label: state.watchOnlyWallet!.label,
        masterFingerprint: state.watchOnlyWallet!.masterFingerprint,
        walletSource: state.watchOnlyWallet!.source,
      );

      emit(state.copyWith(importedWallet: wallet));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> parsePastedInput(String value) async {
    emit(state.copyWith(input: value.trim()));
    if (value.length >= 111) {
      try {
        final watchOnlyWallet = await WatchOnlyWalletEntity.parse(value);

        emit(
          state.copyWith(
            watchOnlyWallet: watchOnlyWallet,
            input: value,
            overrideMasterFingerprint: watchOnlyWallet.masterFingerprint,
          ),
        );
      } catch (e) {
        log.info(e.toString());
        emit(state.copyWith(error: 'Invalid watch only format'));
      }
    }
  }

  void onSourceChanged(WalletSource? value) {
    if (value == null) return;
    final watchOnlyWallet = state.watchOnlyWallet!.copyWith(source: value);
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet));
  }
}
