import 'dart:convert';

import 'package:bull_payjoin/src/domain/payjoin_ports.dart';
import 'package:crypto/crypto.dart';

final class PayjoinLogger {
  /// Writes nowhere. For a host that wants the engine silent, and for tests.
  static const PayjoinLogger silent = PayjoinLogger(_NoopPayjoinLogPort());

  final PayjoinLogPort _port;

  const PayjoinLogger(this._port);

  /// Routine activity at the wallet's non-persisted INFO level, such as one poll of many.
  /// The free-form argument is dropped like other text.
  void info(String _, {PayjoinLogRole? role, String? sessionRef}) {
    _write(
      PayjoinLogLevel.info,
      PayjoinLogCode.lifecycle,
      role: role,
      sessionRef: sessionRef,
    );
  }

  /// A persisted FINE milestone with an explicit, stable code.
  void fine(
    String _, {
    required PayjoinLogCode code,
    PayjoinLogRole? role,
    String? sessionRef,
    Object? error,
  }) {
    _write(
      PayjoinLogLevel.fine,
      code,
      role: role,
      sessionRef: sessionRef,
      error: error,
    );
  }

  void warning(
    String _, {
    PayjoinLogCode code = PayjoinLogCode.lifecycle,
    PayjoinLogRole? role,
    String? sessionRef,
    Object? error,
    StackTrace? trace,
  }) {
    _write(
      PayjoinLogLevel.warning,
      code,
      role: role,
      sessionRef: sessionRef,
      error: error,
      trace: trace,
    );
  }

  void severe({
    required String message,
    required PayjoinLogCode code,
    PayjoinLogRole? role,
    String? sessionRef,
    Object? error,
    StackTrace? trace,
  }) {
    _write(
      PayjoinLogLevel.severe,
      code,
      role: role,
      sessionRef: sessionRef,
      error: error,
      trace: trace,
    );
  }

  /// The free-form message is deliberately dropped: call sites compose it, so it could carry a BIP21 URI or a raw txid into the host's logs.
  /// [error] and [trace] are forwarded for diagnosis; the host must sanitize the cause rather than logging foreign exception text verbatim.
  void _write(
    PayjoinLogLevel level,
    PayjoinLogCode code, {
    PayjoinLogRole? role,
    String? sessionRef,
    Object? error,
    StackTrace? trace,
  }) {
    _port.write(
      PayjoinLogEvent(
        level: level,
        code: code,
        role: role,
        sessionRef: _safeSessionRef(sessionRef),
        error: error,
        trace: trace,
      ),
    );
  }

  String? _safeSessionRef(String? value) {
    if (value == null) return null;
    if (value.length == 16 && RegExp(r'^[0-9a-f]{16}$').hasMatch(value)) {
      return value;
    }
    return sha256.convert(utf8.encode(value)).toString().substring(0, 16);
  }
}

final class _NoopPayjoinLogPort implements PayjoinLogPort {
  const _NoopPayjoinLogPort();

  @override
  void write(PayjoinLogEvent event) {}
}
