import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Localized label for an invoice status (shared by the list chips + detail).
String invoiceStatusText(BuildContext context, InvoiceStatus status) {
  return switch (status) {
    InvoiceStatus.unpaid => context.loc.invoiceStatusUnpaid,
    InvoiceStatus.inProgress => context.loc.invoiceStatusInProgress,
    InvoiceStatus.partiallyPaid => context.loc.invoiceStatusPartiallyPaid,
    InvoiceStatus.paid => context.loc.invoiceStatusPaid,
    InvoiceStatus.underpaid => context.loc.invoiceStatusUnderpaid,
    InvoiceStatus.overpaid => context.loc.invoiceStatusOverpaid,
    InvoiceStatus.expired => context.loc.invoiceStatusExpired,
    InvoiceStatus.cancelled => context.loc.invoiceStatusCancelled,
  };
}

/// A single row in the invoices list: status chip + a title (invoice number or
/// description) + the sat amount.
class InvoiceListItem extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;

  const InvoiceListItem({
    super.key,
    required this.invoice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = invoice.invoiceNumber?.trim().isNotEmpty ?? false
        ? invoice.invoiceNumber!
        : (invoice.publicDescription?.trim().isNotEmpty ?? false)
            ? invoice.publicDescription!
            : invoice.id.value;
    return ListTile(
      onTap: onTap,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          _StatusChip(status: invoice.status),
          const Gap(8),
          Text(
            context.loc.invoiceAmountSats(invoice.amountSat),
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final InvoiceStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.border),
      ),
      child: Text(
        invoiceStatusText(context, status),
        style: context.font.labelSmall,
      ),
    );
  }
}
