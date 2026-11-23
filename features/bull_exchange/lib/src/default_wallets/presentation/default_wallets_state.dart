import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/default_wallets/domain/default_wallets_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'default_wallets_state.freezed.dart';

@freezed
abstract class DefaultWalletsState with _$DefaultWalletsState {
  const factory DefaultWalletsState({
    DefaultWallets? defaultWallets,
    @Default(false) bool isLoading,
    @Default(false) bool isSaving,
    BtcNetwork? editingWalletType,
    @Default('') String bitcoinAddressInput,
    @Default('') String lightningAddressInput,
    @Default('') String liquidAddressInput,
    DefaultWalletsFailure? loadError,
    DefaultWalletsFailure? saveError,
    @Default(false) bool saveSuccess,
  }) = _DefaultWalletsState;

  const DefaultWalletsState._();

  bool get hasDefaultWallets => defaultWallets?.hasAnyWallet ?? false;

  String get currentBitcoinAddress => defaultWallets?.bitcoinAddress ?? '';
  String get currentLightningAddress => defaultWallets?.lightningAddress ?? '';
  String get currentLiquidAddress => defaultWallets?.liquidAddress ?? '';

  bool get isEditing => editingWalletType != null;

  String getInputValue(BtcNetwork type) {
    switch (type) {
      case BtcNetwork.bitcoin:
        return bitcoinAddressInput;
      case BtcNetwork.lightning:
        return lightningAddressInput;
      case BtcNetwork.liquid:
        return liquidAddressInput;
    }
  }

  String getCurrentAddress(BtcNetwork type) {
    switch (type) {
      case BtcNetwork.bitcoin:
        return currentBitcoinAddress;
      case BtcNetwork.lightning:
        return currentLightningAddress;
      case BtcNetwork.liquid:
        return currentLiquidAddress;
    }
  }
}
