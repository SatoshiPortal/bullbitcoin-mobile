import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/historical_value/historical_value_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/historical_value.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/historical_value_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What [tx] was worth when it happened, for surfaces that have a
/// [HistoricalValueCubit] in scope.
///
/// The lookup is optional on purpose. A transaction list can be rendered from
/// places that never provide the cubit — `TransactionsByDayList` lives in
/// `core/widgets` and `OngoingSwaps` mounts list rows of its own — and a
/// missing provider must degrade to showing no value, never to a crash.
class TransactionHistoricalValue extends StatelessWidget {
  const TransactionHistoricalValue({
    super.key,
    required this.tx,
    this.showLabel = false,
    this.alignment = CrossAxisAlignment.end,
    this.rangesAllowed = true,
  });

  final Transaction tx;
  final bool showLabel;
  final CrossAxisAlignment alignment;

  /// The transaction list sets this false: a range needs the room the details
  /// screen has, so the list omits those rows.
  final bool rangesAllowed;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<HistoricalValueCubit?>();
    if (cubit == null) return const SizedBox.shrink();

    final currencyCode = cubit.state.currencyCode;
    if (currencyCode == null) return const SizedBox.shrink();

    final value = cubit.state.valueFor(tx);
    if (value == null) return const SizedBox.shrink();
    if (!rangesAllowed && value is RangeValue) return const SizedBox.shrink();

    return HistoricalValueLine(
      value: value,
      currencyCode: currencyCode,
      isIncoming: tx.isIncoming,
      showLabel: showLabel,
      alignment: alignment,
    );
  }
}
