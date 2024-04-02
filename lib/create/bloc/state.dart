import 'package:bb_mobile/_model/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
class CreateWalletState with _$CreateWalletState {
  const factory CreateWalletState({
    /**
     * 
     * SENSITIVE
     * 
     */
    List<String>? mnemonic,
    @Default('') String passPhrase,
    /**
     * 
     * SENSITIVE
     * 
     */
    @Default(false) bool isInstant,
    @Default(true) bool creatingNmemonic,
    @Default('') String errCreatingNmemonic,
    @Default(false) bool saving,
    @Default('') String errSaving,
    @Default(false) bool saved,
    String? walletLabel,
    List<Wallet>? savedWallets,
    @Default(false) bool mainWallet,
  }) = _CreateWalletState;
  const CreateWalletState._();
}
