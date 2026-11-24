import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullFadingLinearProgress,
        BullScrollableColumn,
        BullTypographyX,
        Gap;
import 'package:exchange/steps.dart';
import 'package:material_ui/material_ui.dart';

/// A quoted sell or pay order and its Confirm: Confirm only on a live
/// quote; a refresh in flight is busy; an unavailable quote offers Retry.
class QuoteReviewPage extends StatelessWidget {
  const QuoteReviewPage({
    super.key,
    required this.title,
    required this.rows,
    required this.status,
    required this.onConfirm,
    required this.onRetry,
    required this.onBack,
  });

  final String title;
  final List<(String, String)> rows;
  final QuoteStatus status;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final (busy, live) = switch (status) {
      QuoteLive() => (false, true),
      QuoteRefreshing() || QuoteRetrying() => (true, false),
      QuoteUnavailable() => (false, false),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: BackButton(onPressed: onBack),
      ),
      body: SafeArea(
        child: Column(
          children: [
            BullFadingLinearProgress(
              height: 3,
              trigger: busy,
              backgroundColor: context.appColors.onPrimary,
              foregroundColor: context.appColors.primary,
            ),
            Expanded(
              child: BullScrollableColumn(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const Gap(16),
                  for (final (label, value) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: context.bullType.body.copyWith(
                              color: context.appColors.onSurfaceVariant,
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: Text(
                              value,
                              textAlign: TextAlign.end,
                              maxLines: 2,
                              style: context.bullType.body,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (status is QuoteUnavailable) ...[
                    Text(
                      context.loc.exchangeQuoteUnavailableError,
                      style: context.bullType.body.copyWith(
                        color: context.appColors.error,
                      ),
                    ),
                    const Gap(16),
                    BullButton.secondary(
                      label: context.loc.retry,
                      onPressed: onRetry,
                    ),
                    const Gap(8),
                  ],
                  BullButton.primary(
                    label: context.loc.sellConfirmPayment,
                    onPressed: live ? onConfirm : null,
                  ),
                  const Gap(24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
