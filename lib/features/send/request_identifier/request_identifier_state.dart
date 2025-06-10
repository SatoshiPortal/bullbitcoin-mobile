import 'package:freezed_annotation/freezed_annotation.dart';

part 'request_identifier_state.freezed.dart';

enum RequestIdentifierRedirect { toSend, toNostr }

@freezed
abstract class RequestIdentifierState with _$RequestIdentifierState {
  const factory RequestIdentifierState({
    @Default(null) RequestIdentifierRedirect? redirect,
    @Default('') String rawRequest,
    @Default('') String error,
  }) = _RequestIdentifierState;

  const RequestIdentifierState._();
}
