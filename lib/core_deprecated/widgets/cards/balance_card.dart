import 'package:bb_mobile/core_deprecated/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.balance, required this.onTap});

  final UserBalance balance;

  final Function onTap;

  String _removeTrailingFiatZeros(String value) {
    if (value.endsWith('.00')) {
      return value.replaceAll('.00', '');
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      child: SizedBox(
        height: 60,
        child: Material(
          clipBehavior: .antiAlias,
          elevation: 2,
          color: context.appColors.onPrimary,
          borderRadius: BorderRadius.circular(2),
          child: Row(
            children: [
              const Gap(12),
              BBText(
                '${balance.currencyCode.toUpperCase()} account balance',
                style: context.font.bodyLarge,
                color: context.appColors.secondary,
              ),
              const Spacer(),
              BBText(
                '${_removeTrailingFiatZeros(balance.amount.toStringAsFixed(2))} ${balance.currencyCode.toUpperCase()}',
                style: context.font.bodyLarge,
                color: context.appColors.secondary,
              ),
              const Gap(8),
              Icon(
                Icons.chevron_right,
                color: context.appColors.outline,
                size: 24,
              ),
              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }
}
