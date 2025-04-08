import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_wallet_model.freezed.dart';

@freezed
sealed class PublicWalletModel with _$PublicWalletModel {
  const factory PublicWalletModel.bdk({
    required String externalDescriptor,
    required String internalDescriptor,
    required bool isTestnet,
    required String dbName,
  }) = PublicBdkWalletModel;
  const factory PublicWalletModel.lwk({
    required String combinedCtDescriptor,
    required bool isTestnet,
    required String dbName,
  }) = PublicLwkWalletModel;
  const PublicWalletModel._();
}
