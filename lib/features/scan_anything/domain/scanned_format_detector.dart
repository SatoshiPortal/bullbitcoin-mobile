import 'dart:convert';

import 'package:bb_mobile/features/scan_anything/domain/entities/scanned_content.dart';

abstract final class ScannedFormatDetector {
  static const _labelTypes = {
    'tx',
    'addr',
    'pubkey',
    'input',
    'output',
    'xpub',
  };
  static final _silentPayment = RegExp(
    r'^(t?sp1)[02-9ac-hj-np-z]{100,130}$',
    caseSensitive: false,
  );
  static final _schemeServer = RegExp(
    r'^(ssl|tcp)://([a-zA-Z0-9.-]+):(\d{1,5})/?$',
    caseSensitive: false,
  );
  static final _onionServer = RegExp(
    r'^([a-z2-7]{16,56}\.onion):(\d{1,5})(?::([st]))?$',
    caseSensitive: false,
  );
  static final _suffixServer = RegExp(
    r'^([a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+):(\d{1,5}):([st])$',
    caseSensitive: false,
  );

  static bool isSilentPaymentAddress(String text) =>
      _silentPayment.hasMatch(text);

  static bool isTestnetSilentPaymentAddress(String text) =>
      text.toLowerCase().startsWith('tsp1');

  static ElectrumServerContent? electrumServer(String text) {
    final String host;
    final String portText;
    final bool useSsl;
    if (_schemeServer.firstMatch(text) case final match?) {
      host = match.group(2) ?? '';
      portText = match.group(3) ?? '';
      useSsl = match.group(1)?.toLowerCase() == 'ssl';
    } else if (_onionServer.firstMatch(text) case final match?) {
      host = match.group(1) ?? '';
      portText = match.group(2) ?? '';
      useSsl = match.group(3)?.toLowerCase() == 's';
    } else if (_suffixServer.firstMatch(text) case final match?) {
      host = match.group(1) ?? '';
      portText = match.group(2) ?? '';
      useSsl = match.group(3)?.toLowerCase() == 's';
    } else {
      return null;
    }
    final port = int.tryParse(portText);
    if (host.isEmpty || port == null || port < 1 || port > 65535) return null;
    return ElectrumServerContent(
      host: host.toLowerCase(),
      port: port,
      useSsl: useSsl,
    );
  }

  static int? labelCount(String text) {
    if (!text.startsWith('{')) return null;
    var count = 0;
    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) continue;
      final Object? record;
      try {
        record = json.decode(line);
      } on FormatException {
        return null;
      }
      if (record is! Map<String, dynamic> ||
          !_labelTypes.contains(record['type']) ||
          record['ref'] is! String) {
        return null;
      }
      count++;
    }
    return count == 0 ? null : count;
  }
}
