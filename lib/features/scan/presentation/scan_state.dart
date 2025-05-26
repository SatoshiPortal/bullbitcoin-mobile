import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_state.freezed.dart';

@freezed
abstract class ScanState with _$ScanState {
  const factory ScanState({
    required bool isStreaming,
    required (String, PaymentRequest?) data,
  }) = _ScanState;
  factory ScanState.initial() =>
      const ScanState(isStreaming: false, data: ('', null));
}
