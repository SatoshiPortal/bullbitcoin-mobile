import 'dart:convert';

import 'package:bull_payjoin/src/domain/payjoin_ports.dart';
import 'package:crypto/crypto.dart';

PayjoinLogger log = PayjoinLogger(const _NoopPayjoinLogPort());

void configurePayjoinLogger(PayjoinLogPort port) {
  log = PayjoinLogger(port);
}

final class PayjoinLogger {
  final PayjoinLogPort _port;

  const PayjoinLogger(this._port);

  void info(
    String _, {
    PayjoinLogCode code = PayjoinLogCode.lifecycle,
    String? sessionRef,
  }) {
    _write(PayjoinLogLevel.info, code, sessionRef: sessionRef);
  }

  void warning(
    String _, {
    PayjoinLogCode code = PayjoinLogCode.lifecycle,
    String? sessionRef,
    Object? error,
    StackTrace? trace,
  }) {
    _write(PayjoinLogLevel.warning, code, sessionRef: sessionRef, trace: trace);
  }

  void severe({
    required String message,
    required PayjoinLogCode code,
    String? sessionRef,
    Object? error,
    StackTrace? trace,
  }) {
    _write(PayjoinLogLevel.severe, code, sessionRef: sessionRef, trace: trace);
  }

  void _write(
    PayjoinLogLevel level,
    PayjoinLogCode code, {
    String? sessionRef,
    StackTrace? trace,
  }) {
    _port.write(
      PayjoinLogEvent(
        level: level,
        code: code,
        sessionRef: _safeSessionRef(sessionRef),
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
