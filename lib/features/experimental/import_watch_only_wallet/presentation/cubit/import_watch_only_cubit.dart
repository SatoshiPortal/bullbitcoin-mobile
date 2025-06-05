import 'package:bb_mobile/features/experimental/import_watch_only_wallet/import_watch_only_usecase.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportWatchOnlyCubit extends Cubit<ImportWatchOnlyState> {
  final ImportWatchOnlyUsecase _importWatchOnlyUsecase;

  ImportWatchOnlyCubit({
    WatchOnlyWalletEntity? watchOnlyWallet,
    required ImportWatchOnlyUsecase importWatchOnlyUsecase,
  }) : _importWatchOnlyUsecase = importWatchOnlyUsecase,
       super(ImportWatchOnlyState(watchOnlyWallet: watchOnlyWallet));

  void updateLabel(String label) {
    if (state.watchOnlyWallet == null) return;
    final watchOnlyWallet = state.watchOnlyWallet!.copyWith(label: label);
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet));
  }

  void overrideFingerprint(String fingerprint) {
    if (state.watchOnlyWallet == null) return;
    final watchOnlyWallet = state.watchOnlyWallet!.copyWith(
      fingerprint: fingerprint,
    );
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet));
  }

  Future<void> import() async {
    if (state.watchOnlyWallet == null) return;
    try {
      final wallet = await _importWatchOnlyUsecase(
        extendedPublicKey: state.watchOnlyWallet!.pubkey,
        scriptType: state.watchOnlyWallet!.type,
        label: state.watchOnlyWallet!.label,
      );
      emit(state.copyWith(importedWallet: wallet));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void parseExtendedPublicKey(String value) {
    emit(state.copyWith(publicKey: value));
    if (value.length == 111) {
      try {
        final wallet = WatchOnlyWalletEntity.from(value);
        emit(state.copyWith(watchOnlyWallet: wallet, publicKey: value));
      } catch (e) {
        emit(
          state.copyWith(
            watchOnlyWallet: null,
            error: 'Invalid extended public key',
          ),
        );
      }
    } else {
      emit(state.copyWith(publicKey: value, watchOnlyWallet: null));
    }
  }
}
