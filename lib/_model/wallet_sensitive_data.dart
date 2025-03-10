import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_sensitive_data.freezed.dart';
part 'wallet_sensitive_data.g.dart';

@freezed
class WalletSensitiveData with _$WalletSensitiveData {
  const factory WalletSensitiveData({
    @Default(1) int version,
    @Default('') String name,
    @Default(<String>[]) List<String> mnemonic,
    @Default('') String passphrase,
    @Default('') String network,
    @Default('') String layer,
    @Default('') String type,
    @Default('') String script,
    @Default('') String publicDescriptors,
  }) = _WalletSensitiveData;

  factory WalletSensitiveData.fromJson(Map<String, dynamic> json) =>
      _$WalletSensitiveDataFromJson(json);

  const WalletSensitiveData._();

  bool get isEmpty => mnemonic.isEmpty && passphrase.isEmpty;
}
