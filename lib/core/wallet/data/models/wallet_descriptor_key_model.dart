import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_descriptor_key_model.freezed.dart';

@freezed
abstract class WalletDescriptorKeyModel with _$WalletDescriptorKeyModel {
  const factory WalletDescriptorKeyModel({
    required String id,
    required String signerId,
    required String masterFingerprint,
    required String xpubFingerprint,
    required String xpub,
    required String? derivationPath,
    @Default('') String descriptorPath,
  }) = _WalletDescriptorKeyModel;
}
