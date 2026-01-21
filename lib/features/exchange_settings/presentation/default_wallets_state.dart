import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'default_wallets_state.freezed.dart';

@freezed
abstract class DefaultWalletsState with _$DefaultWalletsState {
  const factory DefaultWalletsState({
    DefaultWallets? defaultWallets,
    @Default(false) bool isLoading,
    @Default(false) bool isSaving,
    WalletAddressType? editingWalletType,
    @Default('') String bitcoinAddressInput,
    @Default('') String lightningAddressInput,
    @Default('') String liquidAddressInput,
    String? loadError,
    String? saveError,
    @Default(false) bool saveSuccess,
  }) = _DefaultWalletsState;

  const DefaultWalletsState._();

  bool get hasDefaultWallets => defaultWallets?.hasAnyWallet ?? false;

  String get currentBitcoinAddress =>
      defaultWallets?.bitcoinAddress ?? '';
  String get currentLightningAddress =>
      defaultWallets?.lightningAddress ?? '';
  String get currentLiquidAddress =>
      defaultWallets?.liquidAddress ?? '';

  bool get isEditing => editingWalletType != null;

  String getInputValue(WalletAddressType type) {
    switch (type) {
      case WalletAddressType.bitcoin:
        return bitcoinAddressInput;
      case WalletAddressType.lightning:
        return lightningAddressInput;
      case WalletAddressType.liquid:
        return liquidAddressInput;
    }
  }

  String getCurrentAddress(WalletAddressType type) {
    switch (type) {
      case WalletAddressType.bitcoin:
        return currentBitcoinAddress;
      case WalletAddressType.lightning:
        return currentLightningAddress;
      case WalletAddressType.liquid:
        return currentLiquidAddress;
    }
  }
}

