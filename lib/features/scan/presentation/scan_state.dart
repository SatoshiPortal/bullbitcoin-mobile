import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/scan/bbqr_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_state.freezed.dart';

@freezed
abstract class ScanState with _$ScanState {
  const factory ScanState({
    @Default('') String data,
    PaymentRequest? paymentRequest,
    @Default(false) bool isCollectingBbqr,
    BbqrOptions? bbqrOptions,
    @Default({}) Map<int, String> bbqr,
    @Default('') String bbqrPsbt,
  }) = _ScanState;

  factory ScanState.initial() => const ScanState();
}
