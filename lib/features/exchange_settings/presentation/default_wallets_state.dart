import 'package:bb_mobile/core/exchange/domain/entity/default_wallet_address.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'default_wallets_state.freezed.dart';

@freezed
sealed class DefaultWalletsState with _$DefaultWalletsState {
  const DefaultWalletsState._();

  const factory DefaultWalletsState({
    @Default(false) bool isLoading,
    @Default(false) bool isSaving,
    DefaultWallets? wallets,
    String? errorMessage,
    String? saveErrorMessage,
    WalletAddressType? editingAddressType,
    WalletAddressType? deletingAddressType,
    @Default('') String bitcoinAddressValue,
    @Default('') String lightningAddressValue,
    @Default('') String liquidAddressValue,
  }) = _DefaultWalletsState;

  bool get hasError => errorMessage != null;
  bool get hasSaveError => saveErrorMessage != null;

  String getAddressValue(WalletAddressType type) {
    switch (type) {
      case WalletAddressType.bitcoin:
        return bitcoinAddressValue;
      case WalletAddressType.lightning:
        return lightningAddressValue;
      case WalletAddressType.liquid:
        return liquidAddressValue;
    }
  }

  DefaultWalletAddress? getWallet(WalletAddressType type) {
    return wallets?.getByType(type);
  }
}

