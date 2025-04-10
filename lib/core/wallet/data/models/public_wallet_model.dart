import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_wallet_model.freezed.dart';

@freezed
sealed class PublicWalletModel with _$PublicWalletModel {
  const factory PublicWalletModel.bdk({
    required String id,
    required String externalDescriptor,
    required String internalDescriptor,
    required bool isTestnet,
  }) = PublicBdkWalletModel;
  const factory PublicWalletModel.lwk({
    required String id,
    required String combinedCtDescriptor,
    required bool isTestnet,
  }) = PublicLwkWalletModel;
  const PublicWalletModel._();

  String get dbName => id;
}
