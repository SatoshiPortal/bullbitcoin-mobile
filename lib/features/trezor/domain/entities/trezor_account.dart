import 'package:freezed_annotation/freezed_annotation.dart';

part 'trezor_account.freezed.dart';

@freezed
abstract class TrezorAccount with _$TrezorAccount {
  const factory TrezorAccount({
    required int accountIndex,
    required String derivationPath,
    required String xpub,
    required String masterFingerprint,
  }) = _TrezorAccount;
}
