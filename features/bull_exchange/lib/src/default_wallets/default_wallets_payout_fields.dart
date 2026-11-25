import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

/// Integrates the host's existing address entry, QR scanning and validation.
typedef DefaultWalletsPayoutFields = ({
  Future<String?> Function(BtcNetwork type, String raw) validate,
  Widget Function({
    required BtcNetwork type,
    required String value,
    required String hint,
    required bool enabled,
    required ValueChanged<String> onChanged,
    required ValueChanged<bool> onValidationChanged,
  })
  buildField,
});
