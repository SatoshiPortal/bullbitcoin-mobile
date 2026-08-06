import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';

part 'request_identifier_state.freezed.dart';

enum RequestIdentifierRedirect { toSend, toNostr }

@freezed
abstract class RequestIdentifierState with _$RequestIdentifierState {
  const factory RequestIdentifierState({
    @Default(null) RequestIdentifierRedirect? redirect,
    @Default('') String rawRequest,
    SendFailure? failure,
  }) = _RequestIdentifierState;

  const RequestIdentifierState._();
}
