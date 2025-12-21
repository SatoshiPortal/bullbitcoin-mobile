import 'package:bb_mobile/core/exchange/domain/entity/default_wallet_address.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_default_wallet_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/default_wallets_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DefaultWalletsCubit extends Cubit<DefaultWalletsState> {
  final GetDefaultWalletsUsecase _getDefaultWalletsUsecase;
  final SaveDefaultWalletUsecase _saveDefaultWalletUsecase;
  final DeleteDefaultWalletUsecase _deleteDefaultWalletUsecase;

  DefaultWalletsCubit({
    required GetDefaultWalletsUsecase getDefaultWalletsUsecase,
    required SaveDefaultWalletUsecase saveDefaultWalletUsecase,
    required DeleteDefaultWalletUsecase deleteDefaultWalletUsecase,
  })  : _getDefaultWalletsUsecase = getDefaultWalletsUsecase,
        _saveDefaultWalletUsecase = saveDefaultWalletUsecase,
        _deleteDefaultWalletUsecase = deleteDefaultWalletUsecase,
        super(const DefaultWalletsState());

  Future<void> loadWallets() async {
    if (state.isLoading) return;

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final wallets = await _getDefaultWalletsUsecase.execute();
      emit(state.copyWith(
        isLoading: false,
        wallets: wallets,
        bitcoinAddressValue: wallets.bitcoin?.address ?? '',
        lightningAddressValue: wallets.lightning?.address ?? '',
        liquidAddressValue: wallets.liquid?.address ?? '',
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  void updateAddressValue(WalletAddressType type, String value) {
    switch (type) {
      case WalletAddressType.bitcoin:
        emit(state.copyWith(bitcoinAddressValue: value));
      case WalletAddressType.lightning:
        emit(state.copyWith(lightningAddressValue: value));
      case WalletAddressType.liquid:
        emit(state.copyWith(liquidAddressValue: value));
    }
  }

  void setEditingAddressType(WalletAddressType? type) {
    emit(state.copyWith(editingAddressType: type, saveErrorMessage: null));
  }

  void setDeletingAddressType(WalletAddressType? type) {
    emit(state.copyWith(deletingAddressType: type, saveErrorMessage: null));
  }

  void cancelEditing() {
    setEditingAddressType(null);
    // Reset values to current wallet values
    emit(state.copyWith(
      bitcoinAddressValue: state.wallets?.bitcoin?.address ?? '',
      lightningAddressValue: state.wallets?.lightning?.address ?? '',
      liquidAddressValue: state.wallets?.liquid?.address ?? '',
    ));
  }

  Future<void> saveWallet(WalletAddressType addressType) async {
    final address = state.getAddressValue(addressType);
    if (address.isEmpty) {
      emit(state.copyWith(saveErrorMessage: 'Address cannot be empty'));
      return;
    }

    emit(state.copyWith(isSaving: true, saveErrorMessage: null));

    try {
      final existingWallet = state.wallets?.getByType(addressType);
      await _saveDefaultWalletUsecase.execute(
        addressType: addressType,
        address: address,
        existingRecipientId: existingWallet?.recipientId,
      );

      setEditingAddressType(null);
      await loadWallets();
    } catch (e) {
      emit(state.copyWith(
        isSaving: false,
        saveErrorMessage: e.toString(),
      ));
    }
  }

  Future<void> deleteWallet(WalletAddressType addressType) async {
    final wallet = state.wallets?.getByType(addressType);
    if (wallet == null) return;

    emit(state.copyWith(isSaving: true, saveErrorMessage: null));

    try {
      await _deleteDefaultWalletUsecase.execute(
        recipientId: wallet.recipientId,
      );

      setDeletingAddressType(null);
      await loadWallets();
    } catch (e) {
      emit(state.copyWith(
        isSaving: false,
        saveErrorMessage: e.toString(),
      ));
    }
  }
}






