import 'dart:convert';

import 'package:bb_mobile/core/utils/constants.dart';

/// Binds one WebView operation to its original environment and view lifetime.
/// The callback avoids retaining a platform controller in a singleton.
final class ExchangeWebAuthDatasource {
  final bool _isTestnet;
  final Future<Object> Function(String) _evaluateJavaScript;
  final bool Function() _isOpen;

  const ExchangeWebAuthDatasource({
    required this._isTestnet,
    required this._evaluateJavaScript,
    required this._isOpen,
  });

  bool get isOpen => _isOpen();

  Future<Object> generateApiKeyResponse() async {
    if (!isOpen) throw const _ClosedSessionException();
    final baseUrl = _isTestnet
        ? ApiServiceConstants.bbAuthTestUrl
        : ApiServiceConstants.bbAuthUrl;
    final url = jsonEncode('$baseUrl/api/generate-api-key');
    final response = await _evaluateJavaScript('''
      (function() {
        var xhr = new XMLHttpRequest();
        xhr.open('POST', $url, false);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.withCredentials = true;
        try {
          xhr.send(JSON.stringify({apiKeyName: 'test-key-' + new Date().getTime()}));
          if (xhr.status >= 200 && xhr.status < 300) return xhr.responseText;
        } catch (_) {}
        return JSON.stringify({error: 'Authentication request failed'});
      })();
    ''');
    // Preserve cancellation before persistence begins, as the view did before.
    if (!isOpen) throw const _ClosedSessionException();
    return response;
  }
}

final class _ClosedSessionException implements Exception {
  const _ClosedSessionException();
}
