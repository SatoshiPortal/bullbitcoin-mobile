import 'package:bb_mobile/features/experimental/import_watch_only_wallet/domain/usecases/import_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/extended_public_key_entity.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportWatchOnlyCubit extends Cubit<ImportWatchOnlyState> {
  final ImportWatchOnlyWalletUsecase _importWatchOnlyWalletUsecase;

  ImportWatchOnlyCubit({
    required ExtendedPublicKeyEntity pub,
    required ImportWatchOnlyWalletUsecase importWatchOnlyWalletUsecase,
  }) : _importWatchOnlyWalletUsecase = importWatchOnlyWalletUsecase,
       super(ImportWatchOnlyState(pub: pub));

  void updateLabel(String label) {
    final pub = state.pub.copyWith(label: label);
    emit(state.copyWith(pub: pub));
  }

  Future<void> import() async {
    try {
      final wallet = await _importWatchOnlyWalletUsecase(
        extendedPublicKey: state.pub.key,
        scriptType: state.pub.type,
        label: state.pub.label,
      );
      emit(state.copyWith(importedWallet: wallet));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
