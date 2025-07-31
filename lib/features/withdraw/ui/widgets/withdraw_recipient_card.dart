import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class WithdrawRecipientCard extends StatelessWidget {
  final Recipient recipient;
  final bool selected;
  final void Function() onTap;

  const WithdrawRecipientCard({
    super.key,
    required this.recipient,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        recipient.name ??
        (recipient.isCorporate == true
            ? recipient.corporateName
            : recipient.firstname);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? context.colour.primary : context.colour.surface,
          ),
          color: context.colour.onPrimary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    name ?? 'No name',
                    style: context.font.headlineLarge?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                ),
                Radio<bool>(
                  value: true,
                  groupValue: selected,
                  onChanged: (_) => onTap(),
                  activeColor: context.colour.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (recipient.isCorporate == true)
              Text(
                recipient.corporateName ?? 'No corporate name',
                style: context.font.bodyMedium?.copyWith(
                  color: context.colour.secondary,
                ),
              ),
            if (recipient.firstname != null && recipient.lastname != null)
              Text(
                '${recipient.firstname} ${recipient.lastname}',
                style: context.font.bodyMedium?.copyWith(
                  color: context.colour.secondary,
                ),
              ),
            Text(
              recipient.recipientType,
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.secondary,
              ),
            ),
            if (recipient.accountNumber != null)
              Text(
                recipient.accountNumber!,
                style: context.font.bodyMedium?.copyWith(
                  color: context.colour.secondary,
                ),
              ),
            if (recipient.iban != null)
              Text(
                recipient.iban!,
                style: context.font.bodyMedium?.copyWith(
                  color: context.colour.secondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
