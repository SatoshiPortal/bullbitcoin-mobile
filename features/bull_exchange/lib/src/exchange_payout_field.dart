import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

/// Host bridge for the existing destination input, scanner, and parser.
typedef ExchangePayoutField = Widget Function({
  required WalletAddressType type,
  required String value,
  required String label,
  required String hint,
  required bool enabled,
  required ValueChanged<String> onChanged,
  required ValueChanged<String?> onValidated,
});
