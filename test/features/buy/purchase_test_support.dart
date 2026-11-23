import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

Widget emptyPurchaseField({
  required WalletAddressType type,
  required String value,
  required String label,
  required String hint,
  required bool enabled,
  required ValueChanged<String> onChanged,
  required ValueChanged<String?> onValidated,
}) => const SizedBox.shrink();
