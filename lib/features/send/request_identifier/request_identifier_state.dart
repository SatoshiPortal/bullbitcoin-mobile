import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'request_identifier_state.freezed.dart';

@freezed
abstract class RequestIdentifierState with _$RequestIdentifierState {
  const factory RequestIdentifierState({
    @Default(null) Wallet? wallet,
    @Default(null) PaymentRequest? request,
    @Default('') String rawRequest,
    @Default('') String error,
  }) = _RequestIdentifierState;

  const RequestIdentifierState._();
}
