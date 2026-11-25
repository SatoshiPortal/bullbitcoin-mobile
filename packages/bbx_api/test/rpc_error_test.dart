import 'package:bbx_api/src/rpc_error.dart';
import 'package:test/test.dart';

/// A validation error as API-Common's `validationErrorLegacyCompatible`
/// builds it for `createRecipientFiat` (params `{element: {...}}`).
Map<String, Object?> _validationError({
  required Map<String, Object?> fields,
  Map<String, Object?>? errors,
}) => {
  'code': -32602,
  'message': 'Validation error',
  'data': {
    'apiError': {
      'code': 'ERR_API_400',
      'message': 'Invalid request parameters',
      'messageData': <String, Object?>{},
      'fields': fields,
      'requestId': 'req-1',
    },
    'errors': ?errors,
    'requestId': 'req-1',
  },
};

Map<String, Object?> _field(String code, {String message = 'Is required'}) => {
  'code': code,
  'message': message,
  'messageData': {},
  'en': message,
};

void main() {
  group('bbxFieldErrors', () {
    test('reads the refused fields under element with their codes', () {
      final failure = bbxRpcFailure(
        _validationError(
          fields: {
            'element': {
              'email': [_field('ERR_VALIDATION_REQUIRED')],
              'lastname': [_field('ERR_VALIDATION_REQUIRED')],
              'documentType': [
                _field(
                  'ERR_VALIDATION_ENUM',
                  message: 'Must be one of: CC, CE',
                ),
              ],
            },
          },
        ),
      );

      expect(failure.fieldErrors, {
        'email': 'ERR_VALIDATION_REQUIRED',
        'lastname': 'ERR_VALIDATION_REQUIRED',
        'documentType': 'ERR_VALIDATION_ENUM',
      });
      expect(failure.apiCode, 'ERR_API_400');
      expect(failure.requestId, 'req-1');
    });

    test('keeps the first code of a field and nested paths', () {
      expect(
        bbxFieldErrors(
          _validationError(
            fields: {
              'element': {
                'name': [
                  _field('ERR_VALIDATION_STRING'),
                  _field('ERR_VALIDATION_REQUIRED'),
                ],
                'address': {
                  'city': [_field('ERR_VALIDATION_REQUIRED')],
                },
              },
            },
          ),
        ),
        {
          'name': 'ERR_VALIDATION_STRING',
          'address.city': 'ERR_VALIDATION_REQUIRED',
        },
      );
    });

    test('reads the legacy errors when there is no apiError', () {
      expect(
        bbxFieldErrors({
          'code': -32602,
          'message': 'Validation error',
          'data': {
            'errors': {
              'element': {
                'email': [
                  {'code': 'required', 'message': 'Need to be set'},
                ],
                'clabe': [
                  {'code': 'invalid', 'message': 'invalid'},
                ],
              },
            },
          },
        }),
        {'email': 'ERR_VALIDATION_REQUIRED', 'clabe': 'ERR_VALIDATION_INVALID'},
      );
    });

    test('leaves out a path or code that could carry a value', () {
      expect(
        bbxFieldErrors(
          _validationError(
            fields: {
              'element': {
                'ada@example.com': [_field('ERR_VALIDATION_REQUIRED')],
                'email': [_field('Ada Lovelace is not allowed')],
                'clabe': [_field('ERR_VALIDATION_FORMAT')],
              },
            },
          ),
        ),
        {'clabe': 'ERR_VALIDATION_FORMAT'},
      );
    });

    test('an error without fields has none', () {
      expect(
        bbxFieldErrors({
          'code': -32600,
          'message': 'Invalid request',
          'data': {
            'apiError': {'code': 'ERR_API_422', 'message': 'Invalid request'},
          },
        }),
        isEmpty,
      );
      expect(bbxFieldErrors('not an object'), isEmpty);
    });

    test('the failure text names the fields, never their messages', () {
      final failure = bbxRpcFailure(
        _validationError(
          fields: {
            'element': {
              'email': [
                _field(
                  'ERR_VALIDATION_NOT_ALLOWED',
                  message: 'Contains invalid content from: ada@example.com',
                ),
              ],
            },
          },
        ),
      );

      expect(
        '$failure',
        'BbxRpcFailure(code: -32602, apiCode: ERR_API_400, fields: [email], '
            'requestId=req-1)',
      );
    });
  });
}
