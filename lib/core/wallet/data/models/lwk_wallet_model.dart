import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'lwk_wallet_model.freezed.dart';

@freezed
sealed class LwkWalletModel with _$LwkWalletModel {
  const factory LwkWalletModel.public({
    required String combinedCtDescriptor,
    required bool isTestnet,
    required String dbName,
  }) = PublicLwkWalletModel;
  const factory LwkWalletModel.private({
    required String mnemonic,
    required bool isTestnet,
    required String dbName,
  }) = PrivateLwkWalletModel;
  const LwkWalletModel._();
}
