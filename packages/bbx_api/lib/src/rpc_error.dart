import 'package:bbx_api/src/bbx_failure.dart';

/// A server error code that is safe to keep: it never carries account
/// details.
final _apiCodePattern = RegExp(r'^ERR_[A-Z0-9_]{1,64}$');

/// A server request identifier that is safe to keep: an opaque token, never
/// free text.
final _requestIdPattern = RegExp(r'^[A-Za-z0-9:._-]{1,96}$');

/// Reads a JSON-RPC error object.
///
/// [BbxRpcFailure.code] is the error's `code`, [BbxRpcFailure.message] its
/// `message`, [BbxRpcFailure.apiCode] its `data.apiError.code` when that
/// is an `ERR_` code, and [BbxRpcFailure.requestId] its
/// `data.apiError.requestId`, or `data.requestId`, when that is a token.
BbxRpcFailure bbxRpcFailure(Object error) => BbxRpcFailure(
  code: switch (error) {
    {'code': final int? code} => code,
    _ => null,
  },
  message: switch (error) {
    {'message': final String? message} => message,
    _ => null,
  },
  apiCode: switch (error) {
    {'data': {'apiError': {'code': final String code}}}
        when _apiCodePattern.hasMatch(code) =>
      code,
    _ => null,
  },
  requestId: switch (error) {
    {'data': {'apiError': {'requestId': final String id}}}
        when _requestIdPattern.hasMatch(id) =>
      id,
    {'data': {'requestId': final String id}}
        when _requestIdPattern.hasMatch(id) =>
      id,
    _ => null,
  },
);

/// [value] when it is an `ERR_` code, else null.
String? bbxApiCode(Object? value) =>
    value is String && _apiCodePattern.hasMatch(value) ? value : null;
