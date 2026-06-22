import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/transactions/presentation/models/transaction_detail_view.dart';
import 'package:flutter/material.dart';

class TransactionDetailsStatusLabel extends StatelessWidget {
  const TransactionDetailsStatusLabel({super.key, required this.header});

  final TxHeaderView header;

  @override
  Widget build(BuildContext context) {
    final Color? color = switch (header.tone) {
      TxStatusTone.normal => null,
      TxStatusTone.error => context.appColors.error,
      TxStatusTone.errorMuted => context.appColors.error.withValues(alpha: 0.7),
    };

    return BBText(
      header.statusLabel,
      style: context.font.headlineLarge?.copyWith(color: color),
    );
  }
}
