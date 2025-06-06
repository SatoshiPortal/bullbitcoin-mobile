import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/scan/domain/entity/bbqr_options.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_state.freezed.dart';

@freezed
abstract class ScanState with _$ScanState {
  const factory ScanState({
    required (String, PaymentRequest?) data,
    @Default(false) bool isCollectingBbqr,
    @Default(false) bool processingImage,
    BbqrOptions? bbqrOptions,
    @Default({}) Map<int, String> bbqr,
    @Default('') String bbqrPsbt,
  }) = _ScanState;

  factory ScanState.initial() => const ScanState(data: ('', null));
}
