import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bdk_wallet_model.freezed.dart';

@freezed
sealed class BdkWalletModel with _$BdkWalletModel {
  const factory BdkWalletModel.public({
    required String externalDescriptor,
    required String internalDescriptor,
    required bool isTestnet,
    required String dbName,
  }) = PublicBdkWalletModel;
  const factory BdkWalletModel.private({
    required ScriptType scriptType,
    required String mnemonic,
    String? passphrase,
    required bool isTestnet,
    required String dbName,
  }) = PrivateBdkWalletModel;
  const BdkWalletModel._();
}
