import 'package:bb_mobile/features/experimental/import_watch_only_wallet/import_watch_only_usecase.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:satoshifier/satoshifier.dart';

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
      masterFingerprint: fingerprint,
    );
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet));
  }

  Future<void> import() async {
    if (state.watchOnlyWallet == null) return;

    final masterFingerprint =
        state.watchOnlyWallet!.masterFingerprint.isNotEmpty
            ? state.watchOnlyWallet!.masterFingerprint
            : state.watchOnlyWallet!.watchOnly.masterFingerprint;

    try {
      final wallet = await _importWatchOnlyUsecase(
        watchOnly: state.watchOnlyWallet!.watchOnly,
        label: state.watchOnlyWallet!.label,
        masterFingerprint: masterFingerprint,
      );

      emit(state.copyWith(importedWallet: wallet));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> parseExtendedPublicKey(String value) async {
    emit(state.copyWith(publicKey: value.trim()));
    if (value.length >= 111) {
      try {
        final watchOnly = await Satoshifier.parse(value);

        if (watchOnly is! WatchOnly) {
          emit(state.copyWith(error: 'Unsupported watch only format'));
          return;
        }

        final wallet = WatchOnlyWalletEntity(watchOnly: watchOnly);
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
