import 'package:bbx_api/src/bbx_failure.dart';

/// A server error code that is safe to keep: it never carries account
/// details.
final _apiCodePattern = RegExp(r'^ERR_[A-Z0-9_]{1,64}$');

/// Reads a JSON-RPC error object.
///
/// [BbxRpcFailure.code] is the error's `code`, [BbxRpcFailure.message] its
/// `message`, and [BbxRpcFailure.apiCode] its `data.apiError.code` when that
/// is an `ERR_` code.
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
);

/// [value] when it is an `ERR_` code, else null.
String? bbxApiCode(Object? value) =>
    value is String && _apiCodePattern.hasMatch(value) ? value : null;
