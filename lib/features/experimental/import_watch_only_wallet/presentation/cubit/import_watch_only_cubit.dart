import 'package:bb_mobile/features/experimental/import_watch_only_wallet/extended_public_key_entity.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/import_watch_only_usecase.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportWatchOnlyCubit extends Cubit<ImportWatchOnlyState> {
  final ImportWatchOnlyUsecase _importWatchOnlyUsecase;

  ImportWatchOnlyCubit({
    required ExtendedPublicKeyEntity pub,
    required ImportWatchOnlyUsecase importWatchOnlyUsecase,
  }) : _importWatchOnlyUsecase = importWatchOnlyUsecase,
       super(ImportWatchOnlyState(pub: pub));

  void updateLabel(String label) {
    final pub = state.pub.copyWith(label: label);
    emit(state.copyWith(pub: pub));
  }

  Future<void> import() async {
    try {
      final wallet = await _importWatchOnlyUsecase(
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
