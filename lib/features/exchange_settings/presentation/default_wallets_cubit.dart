import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_default_wallet_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/default_wallets_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DefaultWalletsCubit extends Cubit<DefaultWalletsState> {
  DefaultWalletsCubit({
    required GetDefaultWalletsUsecase getDefaultWalletsUsecase,
    required SaveDefaultWalletUsecase saveDefaultWalletUsecase,
    required DeleteDefaultWalletUsecase deleteDefaultWalletUsecase,
  }) : _getDefaultWalletsUsecase = getDefaultWalletsUsecase,
       _saveDefaultWalletUsecase = saveDefaultWalletUsecase,
       _deleteDefaultWalletUsecase = deleteDefaultWalletUsecase,
       super(const DefaultWalletsState());

  final GetDefaultWalletsUsecase _getDefaultWalletsUsecase;
  final SaveDefaultWalletUsecase _saveDefaultWalletUsecase;
  final DeleteDefaultWalletUsecase _deleteDefaultWalletUsecase;

  Future<void> init() async {
    await loadDefaultWallets();
  }

  Future<void> loadDefaultWallets() async {
    emit(
      state.copyWith(
        isLoading: true,
        loadError: null,
        saveError: null,
        saveSuccess: false,
      ),
    );

    try {
      final wallets = await _getDefaultWalletsUsecase.execute();

      emit(
        state.copyWith(
          isLoading: false,
          defaultWallets: wallets,
          bitcoinAddressInput: wallets.bitcoinAddress,
          lightningAddressInput: wallets.lightningAddress,
          liquidAddressInput: wallets.liquidAddress,
        ),
      );
    } catch (e) {
      log.severe('Failed to load default wallets: $e');
      emit(
        state.copyWith(
          isLoading: false,
          loadError: 'Failed to load default wallets',
        ),
      );
    }
  }

  void startEditing(WalletAddressType type) {
    emit(state.copyWith(editingWalletType: type, saveError: null));
  }

  void cancelEditing() {
    emit(
      state.copyWith(
        editingWalletType: null,
        bitcoinAddressInput: state.currentBitcoinAddress,
        lightningAddressInput: state.currentLightningAddress,
        liquidAddressInput: state.currentLiquidAddress,
        saveError: null,
      ),
    );
  }

  void updateBitcoinAddress(String value) {
    emit(state.copyWith(bitcoinAddressInput: value));
  }

  void updateLightningAddress(String value) {
    emit(state.copyWith(lightningAddressInput: value));
  }

  void updateLiquidAddress(String value) {
    emit(state.copyWith(liquidAddressInput: value));
  }

  void updateAddress(WalletAddressType type, String value) {
    switch (type) {
      case WalletAddressType.bitcoin:
        updateBitcoinAddress(value);
      case WalletAddressType.lightning:
        updateLightningAddress(value);
      case WalletAddressType.liquid:
        updateLiquidAddress(value);
    }
  }

  Future<void> saveWallet(WalletAddressType type) async {
    final address = state.getInputValue(type);

    if (address.isEmpty) {
      emit(state.copyWith(saveError: 'Address cannot be empty'));
      return;
    }

    emit(
      state.copyWith(
        isSaving: true,
        saveError: null,
        saveSuccess: false,
      ),
    );

    try {
      final existingWallet = state.defaultWallets?.getWallet(type);

      final savedWallet = await _saveDefaultWalletUsecase.execute(
        walletType: type,
        address: address,
        existingRecipientId: existingWallet?.recipientId,
      );

      final updatedWallets = _updateWalletInState(type, savedWallet);

      emit(
        state.copyWith(
          isSaving: false,
          defaultWallets: updatedWallets,
          editingWalletType: null,
          saveSuccess: true,
        ),
      );

      await Future<void>.delayed(const Duration(seconds: 2));
      if (!isClosed) {
        emit(state.copyWith(saveSuccess: false));
      }
    } catch (e) {
      log.severe('Failed to save wallet: $e');
      emit(
        state.copyWith(
          isSaving: false,
          saveError: 'Failed to save wallet address',
        ),
      );
    }
  }

  Future<void> deleteWallet(WalletAddressType type) async {
    final existingWallet = state.defaultWallets?.getWallet(type);

    if (existingWallet?.recipientId == null) {
      return;
    }

    emit(
      state.copyWith(
        isSaving: true,
        saveError: null,
      ),
    );

    try {
      await _deleteDefaultWalletUsecase.execute(
        recipientId: existingWallet!.recipientId!,
      );

      final updatedWallets = _removeWalletFromState(type);

      emit(
        state.copyWith(
          isSaving: false,
          defaultWallets: updatedWallets,
          saveSuccess: true,
        ),
      );

      _clearInputForType(type);

      await Future<void>.delayed(const Duration(seconds: 2));
      if (!isClosed) {
        emit(state.copyWith(saveSuccess: false));
      }
    } catch (e) {
      log.severe('Failed to delete wallet: $e');
      emit(
        state.copyWith(
          isSaving: false,
          saveError: 'Failed to delete wallet address',
        ),
      );
    }
  }

  void clearError() {
    emit(state.copyWith(saveError: null, loadError: null));
  }

  DefaultWallets _updateWalletInState(
    WalletAddressType type,
    DefaultWallet wallet,
  ) {
    final current = state.defaultWallets ?? const DefaultWallets();

    switch (type) {
      case WalletAddressType.bitcoin:
        return current.copyWith(bitcoin: wallet);
      case WalletAddressType.lightning:
        return current.copyWith(lightning: wallet);
      case WalletAddressType.liquid:
        return current.copyWith(liquid: wallet);
    }
  }

  DefaultWallets _removeWalletFromState(WalletAddressType type) {
    final current = state.defaultWallets ?? const DefaultWallets();

    switch (type) {
      case WalletAddressType.bitcoin:
        return DefaultWallets(
          lightning: current.lightning,
          liquid: current.liquid,
        );
      case WalletAddressType.lightning:
        return DefaultWallets(
          bitcoin: current.bitcoin,
          liquid: current.liquid,
        );
      case WalletAddressType.liquid:
        return DefaultWallets(
          bitcoin: current.bitcoin,
          lightning: current.lightning,
        );
    }
  }

  void _clearInputForType(WalletAddressType type) {
    switch (type) {
      case WalletAddressType.bitcoin:
        emit(state.copyWith(bitcoinAddressInput: ''));
      case WalletAddressType.lightning:
        emit(state.copyWith(lightningAddressInput: ''));
      case WalletAddressType.liquid:
        emit(state.copyWith(liquidAddressInput: ''));
    }
  }
}

