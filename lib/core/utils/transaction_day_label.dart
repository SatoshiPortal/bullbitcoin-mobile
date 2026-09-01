import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Header for a day group in a transaction list: the pending bucket, the two
/// most recent days by name, then a date that keeps the year only once it is
/// no longer the current one.
String transactionDayLabel(BuildContext context, DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  if (date.compareTo(today) > 0) return context.loc.transactionListPending;
  if (date.isAtSameMomentAs(today)) return context.loc.transactionListToday;
  if (date.isAtSameMomentAs(yesterday)) {
    return context.loc.transactionListYesterday;
  }
  return date.year == now.year
      ? DateFormat.MMMMd().format(date)
      : DateFormat.yMMMMd().format(date);
}
