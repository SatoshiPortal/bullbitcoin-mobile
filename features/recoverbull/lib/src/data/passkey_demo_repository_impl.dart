import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:primitives/primitives.dart';

import '../domain/repositories/passkey_demo_repository.dart';
import '../domain/passkey_demo_operation.dart';

final class PasskeyDemoRepositoryImpl implements PasskeyDemoRepository {
  static const _channel = MethodChannel(
    'com.bullbitcoin.mobile/recoverbull_passkey_demo',
  );
  static int _nextId = 0;
  static const _timeout = Duration(seconds: 15);

  static final _origin = Uri.parse('http://127.0.0.1:8443');
  static const _dummyContent =
      'Dummy RecoverBull content: no wallet, secret, or backup.';

  final http.Client Function() _clientFactory;

  PasskeyDemoRepositoryImpl({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? _directClient;

  static http.Client _directClient() {
    final client = HttpClient()..findProxy = (_) => 'DIRECT';
    return IOClient(client);
  }

  @override
  Future<Result<String, PasskeyDemoFailure>> register(
    PasskeyDemoOperation operation,
  ) => _run(
    operation: operation,
    ceremony: 'register',
    method: 'create',
    parameters: const {},
    resultField: 'accountId',
  );

  @override
  Future<Result<String, PasskeyDemoFailure>> open(
    String accountId,
    PasskeyDemoOperation operation,
  ) => _run(
    operation: operation,
    ceremony: 'authenticate',
    method: 'get',
    parameters: {'accountId': accountId},
    resultField: 'content',
  );

  Future<Result<String, PasskeyDemoFailure>> _run({
    required PasskeyDemoOperation operation,
    required String ceremony,
    required String method,
    required Map<String, Object?> parameters,
    required String resultField,
  }) async {
    final client = _clientFactory();
    try {
      final challenge = await _post(client, '/$ceremony/options', parameters);
      if (challenge case {
        'sessionId': final String sessionId,
        'options': final Map<String, dynamic> options,
      }) {
        if (!await operation.isAllowed()) {
          return const Err(PasskeyDemoFailure.disabled);
        }
        final id = '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
        operation.onCancel(() {
          unawaited(
            _channel.invokeMethod<void>('cancel', id).catchError((Object _) {}),
          );
        });
        if (operation.isCancelled) {
          return const Err(PasskeyDemoFailure.disabled);
        }
        final response = await _channel.invokeMethod<String>(method, {
          'id': id,
          'options': jsonEncode(options),
        });
        operation.onCancel(null);
        if (response != null) {
          if (!await operation.isAllowed()) {
            return const Err(PasskeyDemoFailure.disabled);
          }
          final verified = await _post(client, '/$ceremony/verify', {
            'sessionId': sessionId,
            'credential': jsonDecode(response),
          });
          if (verified[resultField] case final String result
              when result.isNotEmpty) {
            if (ceremony == 'authenticate') {
              if (result != _dummyContent) {
                return const Err(PasskeyDemoFailure.unavailable);
              }
              return const Ok(_dummyContent);
            }
            return Ok(result);
          }
        }
      }
      return const Err(PasskeyDemoFailure.unavailable);
    } on PlatformException catch (error) {
      return Err(
        error.code == 'cancelled'
            ? PasskeyDemoFailure.cancelled
            : PasskeyDemoFailure.unavailable,
      );
    } on Exception {
      return const Err(PasskeyDemoFailure.unavailable);
    } finally {
      operation.onCancel(null);
      client.close();
    }
  }

  Future<Map<String, dynamic>> _post(
    http.Client client,
    String path,
    Map<String, Object?> body,
  ) async {
    final request = http.Request('POST', _origin.replace(path: path))
      ..followRedirects = false
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(body);
    final response = await client.send(request).timeout(_timeout);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(
        await response.stream.bytesToString().timeout(_timeout),
      );
      if (decoded is Map<String, dynamic>) return decoded;
    }
    throw const FormatException('Invalid passkey demo response');
  }
}
