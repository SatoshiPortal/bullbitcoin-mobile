import 'package:intl/intl.dart';

/// Shared date formatting for transaction detail rows.
String formatTxDate(DateTime date) => DateFormat('MMM d, y, h:mm a').format(date);
