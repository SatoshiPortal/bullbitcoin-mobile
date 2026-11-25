import 'package:bbx_api/src/bbx_failure.dart';

/// A server error code that is safe to keep: it never carries account
/// details.
final _apiCodePattern = RegExp(r'^ERR_[A-Z0-9_]{1,64}$');

/// A server request identifier that is safe to keep: an opaque token, never
/// free text.
final _requestIdPattern = RegExp(r'^[A-Za-z0-9:._-]{1,96}$');

/// A request field path that is safe to keep: identifiers joined by dots,
/// never free text.
final _fieldPattern = RegExp(
  r'^[A-Za-z0-9_]{1,64}(\.[A-Za-z0-9_]{1,64}){0,5}$',
);

/// A validation code that is safe to keep (`ERR_VALIDATION_REQUIRED`).
final _validationCodePattern = RegExp(r'^ERR_VALIDATION_[A-Z_]{1,48}$');

/// A legacy validator name (`required`, `email`, `in`).
final _legacyCodePattern = RegExp(r'^[A-Za-z][A-Za-z_-]{0,39}$');

/// Reads a JSON-RPC error object.
///
/// [BbxRpcFailure.code] is the error's `code`, [BbxRpcFailure.message] its
/// `message`, [BbxRpcFailure.apiCode] its `data.apiError.code` when that
/// is an `ERR_` code, [BbxRpcFailure.fieldErrors] the refused fields of
/// `data.apiError.fields` (or of the legacy `data.errors`), and
/// [BbxRpcFailure.requestId] its `data.apiError.requestId`, or
/// `data.requestId`, when that is a token.
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
  fieldErrors: bbxFieldErrors(error),
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

/// The refused fields of the JSON-RPC [error], each with its
/// `ERR_VALIDATION_` code.
///
/// API-Common's validation error (`ApiErrorCommon.invalidParams` and
/// `validationErrorLegacyCompatible`) nests a list of
/// `{code, message, ...}` under each field path, inside the request's
/// params: `{"element": {"email": [{"code": "ERR_VALIDATION_REQUIRED"}]}}`.
/// `data.apiError.fields` is read first; the legacy `data.errors`, whose
/// codes are validator names (`required`), only without it. The leading
/// `element` is dropped from each path. A path or code that doesn't match
/// its safe pattern is left out, so no value of the request is kept.
Map<String, String> bbxFieldErrors(Object error) {
  final fields = <String, String>{};
  switch (error) {
    case {'data': {'apiError': {'fields': final Map<String, Object?> tree}}}:
      _collectFields(tree, const [], fields, _apiFieldCode);
    case {'data': {'errors': final Map<String, Object?> tree}}:
      _collectFields(tree, const [], fields, _legacyFieldCode);
  }
  return Map.unmodifiable(fields);
}

String? _apiFieldCode(Object? code) =>
    code is String && _validationCodePattern.hasMatch(code) ? code : null;

String? _legacyFieldCode(Object? code) {
  if (code is! String || !_legacyCodePattern.hasMatch(code)) return null;
  return code == 'required'
      ? 'ERR_VALIDATION_REQUIRED'
      : 'ERR_VALIDATION_${code.toUpperCase().replaceAll('-', '_')}';
}

void _collectFields(
  Object? node,
  List<String> path,
  Map<String, String> into,
  String? Function(Object? code) codeOf,
) {
  switch (node) {
    case final Map<String, Object?> map:
      for (final MapEntry(:key, :value) in map.entries) {
        _collectFields(value, [...path, key], into, codeOf);
      }
    case final List<Object?> list:
      final codes = [
        for (final item in list)
          if (item case {'code': final Object? code}) codeOf(code),
      ];
      final code = codes.nonNulls.firstOrNull;
      if (code != null) {
        final field = (path.firstOrNull == 'element' ? path.skip(1) : path)
            .join('.');
        if (_fieldPattern.hasMatch(field)) into.putIfAbsent(field, () => code);
        return;
      }
      for (final (index, item) in list.indexed) {
        if (item is Map<String, Object?> && !item.containsKey('code')) {
          _collectFields(item, [...path, '$index'], into, codeOf);
        }
      }
  }
}
