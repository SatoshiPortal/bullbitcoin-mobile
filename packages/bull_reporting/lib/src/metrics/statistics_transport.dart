import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bull_logger/bull_logger.dart' show log;

import 'sentry_endpoint.dart';

/// Best-effort statistics transport independent of the error-reporting SDK.
/// The caller supplies the network gate and manages consent.
final class StatisticsTransport {
  final Uri? _endpoint;
  final String _release;
  final String _environment;
  final Future<bool> Function() _canSend;
  final Random _random = Random.secure();
  final List<Map<String, Object>> _pending = [];
  HttpClient? _client;
  Timer? _timer;
  Future<void>? _sending;

  StatisticsTransport(
    String dsn,
    this._release,
    this._environment,
    this._canSend,
  ) : _endpoint = parseSentryEndpoint(dsn);

  /// Whether the endpoint and mainnet label permit sending observations.
  bool get available => _endpoint != null && _environment == 'mainnet';

  /// Disabling drops queued observations and aborts in-flight connections.
  /// Bytes already received by the server cannot be recalled.
  void updateConsent(bool enabled) {
    if (!enabled) {
      final client = _client;
      _client = null;
      _timer?.cancel();
      _timer = null;
      _pending.clear();
      client?.close(force: true);
    } else if (available && _client == null) {
      _client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    }
  }

  void installationActive(DateTime instant) {
    if (_client == null || _pending.length >= 40) return;
    _pending.add({
      'name': 'bull.installation.active',
      'type': 'counter',
      'value': 1,
      'timestamp': instant.toUtc().millisecondsSinceEpoch / 1000,
      'trace_id': List.generate(
        16,
        (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
      'attributes': {
        'sentry.release': {'type': 'string', 'value': _release},
        'sentry.environment': {'type': 'string', 'value': _environment},
      },
    });
    _timer ??= Timer(const Duration(seconds: 2), () => unawaited(flush()));
  }

  /// Sends the current in-memory batch. There is no offline queue or retry.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final sending = _sending;
    if (sending != null) return sending.then((_) => flush());
    final client = _client;
    final endpoint = _endpoint;
    if (client == null || endpoint == null || _pending.isEmpty) {
      return Future.value();
    }
    final batch = List.of(_pending);
    _pending.clear();
    return _sending = _send(client, endpoint, batch).whenComplete(() {
      _sending = null;
    });
  }

  Future<void> _send(
    HttpClient client,
    Uri endpoint,
    List<Map<String, Object>> batch,
  ) async {
    HttpClientRequest? request;
    try {
      if (!await _canSend() || !identical(_client, client)) return;
      final payload = utf8.encode(jsonEncode({'items': batch}));
      final header = utf8.encode(
        '{}\n${jsonEncode({'type': 'trace_metric', 'item_count': batch.length, 'length': payload.length, 'content_type': 'application/vnd.sentry.items.trace-metric+json'})}\n',
      );
      request = await client
          .postUrl(endpoint)
          .timeout(const Duration(seconds: 4));
      if (!await _canSend() || !identical(_client, client)) {
        request.abort();
        return;
      }
      request.followRedirects = false;
      request.headers.contentType = ContentType(
        'application',
        'x-sentry-envelope',
      );
      request.add(header);
      request.add(payload);
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      await response.drain<void>().timeout(const Duration(seconds: 4));
      final status = response.statusCode;
      if (status < 200 || status >= 300) {
        // Best effort: no retry. Only the status code is recorded, never the
        // endpoint, key, response body or payload.
        log.warning('Statistics delivery rejected, status $status');
      }
    } on Exception {
      request?.abort();
      // Statistics must not interfere with the wallet.
    }
  }
}
