import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/delete_exchange_default_wallet_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_default_wallets_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/save_exchange_default_wallet_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/default_wallets_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

class DefaultWalletsCubit extends Cubit<DefaultWalletsState> {
  final GetExchangeDefaultWalletsUsecase _getExchangeDefaultWalletsUsecase;
  final SaveExchangeDefaultWalletUsecase _saveExchangeDefaultWalletUsecase;
  final DeleteExchangeDefaultWalletUsecase _deleteExchangeDefaultWalletUsecase;

  /// Incremented per save so a stale success-tick timer can identify itself.
  int _saveSuccessGeneration = 0;

  DefaultWalletsCubit({
    required GetExchangeDefaultWalletsUsecase getDefaultWalletsUsecase,
    required SaveExchangeDefaultWalletUsecase saveDefaultWalletUsecase,
    required DeleteExchangeDefaultWalletUsecase deleteDefaultWalletUsecase,
  }) : _getExchangeDefaultWalletsUsecase = getDefaultWalletsUsecase,
       _saveExchangeDefaultWalletUsecase = saveDefaultWalletUsecase,
       _deleteExchangeDefaultWalletUsecase = deleteDefaultWalletUsecase,
       super(const DefaultWalletsState());

  Future<void> init() async {
    await loadDefaultWallets();
  }

  Future<void> loadDefaultWallets() async {
    emit(
      state.copyWith(
        isLoading: true,
        loadFailure: null,
        saveFailure: null,
        saveSuccess: false,
      ),
    );

    final result = await _getExchangeDefaultWalletsUsecase.execute();
    if (isClosed) return;

    emit(switch (result) {
      Ok(:final value) => state.copyWith(
        isLoading: false,
        defaultWallets: value,
        bitcoinAddressInput: value.bitcoinAddress,
        lightningAddressInput: value.lightningAddress,
        liquidAddressInput: value.liquidAddress,
      ),
      Err(:final failure) => state.copyWith(
        isLoading: false,
        loadFailure: failure,
      ),
    });
  }

  void startEditing(WalletAddressType type) {
    emit(state.copyWith(editingWalletType: type, saveFailure: null));
  }

  void cancelEditing() {
    emit(
      state.copyWith(
        editingWalletType: null,
        bitcoinAddressInput: state.currentBitcoinAddress,
        lightningAddressInput: state.currentLightningAddress,
        liquidAddressInput: state.currentLiquidAddress,
        saveFailure: null,
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

    // Rejected synchronously so an instant validation error does not flash a
    // progress indicator. The use-case enforces the same rule regardless.
    final invalid = SaveExchangeDefaultWalletUsecase.validate(address);
    if (invalid != null) {
      emit(state.copyWith(saveFailure: invalid, saveSuccess: false));
      return;
    }

    emit(state.copyWith(isSaving: true, saveFailure: null, saveSuccess: false));

    final existingWallet = state.defaultWallets?.getWallet(type);

    final result = await _saveExchangeDefaultWalletUsecase.execute(
      walletType: type,
      address: address,
      existingRecipientId: existingWallet?.recipientId,
    );
    if (isClosed) return;

    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(isSaving: false, saveFailure: failure));
        return;
      case Ok(:final value):
        emit(
          state.copyWith(
            isSaving: false,
            defaultWallets: _updateWalletInState(type, value),
            editingWalletType: null,
            saveSuccess: true,
          ),
        );
    }

    await _clearSaveSuccessAfterDelay();
  }

  Future<void> deleteWallet(WalletAddressType type) async {
    final existingWallet = state.defaultWallets?.getWallet(type);
    final recipientId = existingWallet?.recipientId;

    if (existingWallet == null || recipientId == null) {
      return;
    }

    emit(state.copyWith(isSaving: true, saveFailure: null));

    final result = await _deleteExchangeDefaultWalletUsecase.execute(
      recipientId: recipientId,
      walletType: type,
      address: existingWallet.address,
    );
    if (isClosed) return;

    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(isSaving: false, saveFailure: failure));
        return;
      case Ok():
        emit(
          state.copyWith(
            isSaving: false,
            defaultWallets: _removeWalletFromState(type),
            saveSuccess: true,
          ),
        );
    }

    _clearInputForType(type);
    await _clearSaveSuccessAfterDelay();
  }

  void clearError() {
    emit(state.copyWith(saveFailure: null, loadFailure: null));
  }

  /// The success tick is transient; drop it once the user has had time to see
  /// it. Each call claims a generation so an earlier timer cannot clear a
  /// later save's tick, and a closed cubit is never emitted into.
  Future<void> _clearSaveSuccessAfterDelay() async {
    final generation = ++_saveSuccessGeneration;
    await Future<void>.delayed(const Duration(seconds: 2));
    if (isClosed || generation != _saveSuccessGeneration) return;
    emit(state.copyWith(saveSuccess: false));
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
