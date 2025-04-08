import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'private_wallet_model.freezed.dart';

@freezed
sealed class PrivateWalletModel with _$PrivateWalletModel {
  const factory PrivateWalletModel.bdk({
    required ScriptType scriptType,
    required String mnemonic,
    String? passphrase,
    required bool isTestnet,
    required String dbName,
  }) = PrivateBdkWalletModel;

  const factory PrivateWalletModel.lwk({
    required String mnemonic,
    required bool isTestnet,
    required String dbName,
  }) = PrivateLwkWalletModel;
  const PrivateWalletModel._();
}
