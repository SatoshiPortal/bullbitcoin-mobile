import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportWatchOnlyCubit extends Cubit<ImportWatchOnlyState> {
  final ImportWatchOnlyDescriptorUsecase _importWatchOnlyDescriptorUsecase;
  final ImportWatchOnlyXpubUsecase _importWatchOnlyXpubUsecase;

  ImportWatchOnlyCubit({
    WatchOnlyWalletEntity? watchOnlyWallet,
    required ImportWatchOnlyDescriptorUsecase importWatchOnlyDescriptorUsecase,
    required ImportWatchOnlyXpubUsecase importWatchOnlyXpubUsecase,
  }) : _importWatchOnlyDescriptorUsecase = importWatchOnlyDescriptorUsecase,
       _importWatchOnlyXpubUsecase = importWatchOnlyXpubUsecase,
       super(ImportWatchOnlyState(watchOnlyWallet: watchOnlyWallet));

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
    emit(state.copyWith(error: ''));

    try {
      if (state.watchOnlyWallet == null) throw 'No watch-only wallet';
      if (state.watchOnlyWallet!.label.isEmpty) throw 'Label required';

      if (state.watchOnlyWallet is WatchOnlyDescriptorEntity) {
        final entity = state.watchOnlyWallet! as WatchOnlyDescriptorEntity;
        final importedWallet = await _importWatchOnlyDescriptorUsecase(
          watchOnlyDescriptor: entity,
        );
        emit(state.copyWith(importedWallet: importedWallet));
      } else if (state.watchOnlyWallet is WatchOnlyXpubEntity) {
        final entity = state.watchOnlyWallet! as WatchOnlyXpubEntity;
        final importedWallet = await _importWatchOnlyXpubUsecase(
          watchOnlyXpub: entity,
        );
        emit(state.copyWith(importedWallet: importedWallet));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> parsePastedInput(String input) async {
    final value = input.trim();
    emit(state.copyWith(input: value));
    if (value.length >= 111) {
      try {
        final entity = await WatchOnlyWalletEntity.parse(value);
        emit(state.copyWith(watchOnlyWallet: entity));
      } catch (e) {
        log.info(e.toString());
        emit(state.copyWith(error: 'Invalid watch only format'));
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
}
