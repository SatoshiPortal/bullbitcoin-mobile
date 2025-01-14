import 'package:bb_mobile/_model/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class WalletState with _$WalletState {
  const factory WalletState({
    required Wallet wallet,
    @Default(false) bool syncing,
    @Default('') String errSyncing,
  }) = _WalletState;
  const WalletState._();
}
