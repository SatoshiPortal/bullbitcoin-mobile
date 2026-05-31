import 'package:freezed_annotation/freezed_annotation.dart';

part 'trezor_signed_psbt.freezed.dart';

@freezed
abstract class TrezorSignedPsbt with _$TrezorSignedPsbt {
  const factory TrezorSignedPsbt({
    required String serializedTxHex,
    String? txid,
  }) = _TrezorSignedPsbt;
}
