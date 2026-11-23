import 'package:bull_exchange/src/default_wallets/domain/validate_default_wallet_destination_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/default_wallets/domain/default_wallets_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_exchange/src/default_wallets/presentation/default_wallets_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/usecases/delete_default_wallet_usecase.dart';
import '../domain/usecases/get_default_wallets_usecase.dart';
import '../domain/usecases/save_default_wallet_usecase.dart';

class DefaultWalletsCubit extends Cubit<DefaultWalletsState> {
  DefaultWalletsCubit({
    required this._validateDestination,
    required Exchange exchange,
  }) : _getDefaultWallets = GetDefaultWalletsUsecase(exchange),
       _saveDefaultWallet = SaveDefaultWalletUsecase(exchange),
       _deleteDefaultWallet = DeleteDefaultWalletUsecase(exchange),
       super(const DefaultWalletsState());

  final ValidateDefaultWalletDestinationUsecase _validateDestination;
  int _destinationGeneration = 0;

  final GetDefaultWalletsUsecase _getDefaultWallets;
  final SaveDefaultWalletUsecase _saveDefaultWallet;
  final DeleteDefaultWalletUsecase _deleteDefaultWallet;

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

    final result = await _getDefaultWallets.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(value: final wallets):
        emit(
          state.copyWith(
            isLoading: false,
            defaultWallets: wallets,
            bitcoinAddressInput: wallets.bitcoinAddress,
            lightningAddressInput: wallets.lightningAddress,
            liquidAddressInput: wallets.liquidAddress,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, loadError: failure));
    }
  }

  void startEditing(WalletAddressType type) {
    _destinationGeneration++;
    emit(state.copyWith(editingWalletType: type, saveError: null));
  }

  void cancelEditing() {
    _destinationGeneration++;
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
    _destinationGeneration++;
    emit(state.copyWith(bitcoinAddressInput: value));
  }

  void updateLightningAddress(String value) {
    _destinationGeneration++;
    emit(state.copyWith(lightningAddressInput: value));
  }

  void updateLiquidAddress(String value) {
    _destinationGeneration++;
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
    if (state.isSaving) return;
    if (state.saveError != null || state.saveSuccess) {
      emit(state.copyWith(saveError: null, saveSuccess: false));
    }

    final address = state.getInputValue(type);
    final generation = _destinationGeneration;

    if (address.trim().isEmpty) {
      emit(
        state.copyWith(saveError: const DefaultWalletsEmptyAddressFailure()),
      );
      return;
    }

    emit(state.copyWith(isSaving: true));

    try {
      final normalizedAddress = await _validateDestination.execute(
        type,
        address,
      );
      if (isClosed) return;
      if (generation != _destinationGeneration ||
          state.getInputValue(type) != address) {
        emit(state.copyWith(isSaving: false));
        return;
      }
      if (normalizedAddress == null) {
        emit(
          state.copyWith(
            isSaving: false,
            saveError: DefaultWalletsInvalidAddressFailure(type),
          ),
        );
        return;
      }
      final existingWallet = state.defaultWallets?.getWallet(type);

      final result = await _saveDefaultWallet.execute(
        walletType: type,
        address: normalizedAddress,
        existingRecipientId: existingWallet?.recipientId,
      );

      if (isClosed) return;
      final DefaultWallet savedWallet;
      switch (result) {
        case Ok(:final value):
          savedWallet = value;
        case Err(:final failure):
          emit(
            state.copyWith(
              isSaving: false,
              saveError: failure,
              saveSuccess: false,
            ),
          );
          return;
      }
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
    } on Exception catch (error) {
      if (isClosed) return;
      log.warning('Failed to validate a default wallet: ${error.runtimeType}');
      emit(
        state.copyWith(
          isSaving: false,
          saveError: const DefaultWalletsSaveFailure(),
          saveSuccess: false,
        ),
      );
    }
  }

  Future<void> deleteWallet(WalletAddressType type) async {
    final existingWallet = state.defaultWallets?.getWallet(type);

    final recipientId = existingWallet?.recipientId;
    if (existingWallet == null || recipientId == null) {
      return;
    }

    emit(state.copyWith(isSaving: true, saveError: null, saveSuccess: false));

    final result = await _deleteDefaultWallet.execute(
      recipientId: recipientId,
      walletType: type,
      address: existingWallet.address,
    );
    if (isClosed) return;

    if (result case Err(:final failure)) {
      emit(
        state.copyWith(isSaving: false, saveError: failure, saveSuccess: false),
      );
      return;
    }
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
        return DefaultWallets(bitcoin: current.bitcoin, liquid: current.liquid);
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
