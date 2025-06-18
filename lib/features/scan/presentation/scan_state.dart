import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_state.freezed.dart';

@freezed
abstract class ScanState with _$ScanState {
  const factory ScanState({
    required (String, PaymentRequest?) data,
    @Default(false) bool processingImage,
  }) = _ScanState;

  factory ScanState.initial() => const ScanState(data: ('', null));
}
