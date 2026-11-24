import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/recipients/presentation/payout_rail_l10n.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/withdraw/presentation/withdraw_flow.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullFadingLinearProgress,
        BullScrollableColumn,
        Gap,
        BullTypographyX;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show FormatAmount;

/// The created withdrawal and its Confirm. [confirm] is null before the
/// first Confirm; afterwards the page shows the confirm step's state: busy
/// while confirming or re-reading, the problem and the exit it allows
/// otherwise. Confirm is never offered while the outcome may be unknown.
class WithdrawReviewPage extends StatelessWidget {
  const WithdrawReviewPage({
    super.key,
    required this.brandAsset,
    required this.recipient,
    required this.order,
    required this.confirm,
    required this.onEvent,
  });

  final String brandAsset;
  final ReadyRecipient recipient;
  final WithdrawOrder order;
  final WithdrawConfirmState? confirm;
  final void Function(WithdrawFlowEvent event) onEvent;

  @override
  Widget build(BuildContext context) {
    final onRail = recipient.chosen.recipient.onRail;
    final account = switch (onRail.accountRows) {
      [final row, ...] => (label: row.field.label(context), value: row.value),
      [] => (label: context.loc.withdrawConfirmBankAccount, value: '-'),
    };
    final confirm = this.confirm;
    final busy = switch (confirm) {
      ConfirmConfirming() || ConfirmVerifying() => true,
      null ||
      ConfirmWriteRefused() ||
      ConfirmFailed() ||
      ConfirmUnverified() ||
      ConfirmConfirmed() ||
      ConfirmSessionEnded() ||
      ConfirmLeft() => false,
    };
    final problem = switch (confirm) {
      ConfirmWriteRefused(:final refusal) => refusal.toTranslated(context),
      ConfirmFailed(:final problem) => problem.toTranslated(context),
      ConfirmUnverified(:final problem) =>
        '${context.loc.withdrawConfirmOutcomeUnknownError}\n'
            '${problem.toTranslated(context)}',
      ConfirmVerifying() => context.loc.exchangeStepVerifying,
      null ||
      ConfirmConfirming() ||
      ConfirmConfirmed() ||
      ConfirmSessionEnded() ||
      ConfirmLeft() => null,
    };
    final label = switch (confirm) {
      ConfirmUnverified() || ConfirmVerifying() =>
        context.loc.withdrawConfirmCheckAgainButton,
      null ||
      ConfirmConfirming() ||
      ConfirmWriteRefused() ||
      ConfirmFailed() ||
      ConfirmConfirmed() ||
      ConfirmSessionEnded() ||
      ConfirmLeft() => context.loc.withdrawConfirmButton,
    };
    return Scaffold(
      appBar: AppBar(title: Image.asset(brandAsset, height: 32, width: 32)),
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
                  const Gap(24),
                  Text(
                    context.loc.withdrawConfirmTitle,
                    style: context.bullType.subtitle
                        .copyWith(fontWeight: FontWeight.w500)
                        .copyWith(color: context.appColors.secondary),
                  ),
                  const Gap(12),
                  _Row(
                    title: context.loc.withdrawConfirmRecipientName,
                    value: onRail.displayName ?? '-',
                  ),
                  const _Divider(),
                  _Row(title: account.label, value: account.value),
                  const _Divider(),
                  _Row(
                    title: context.loc.withdrawConfirmAmount,
                    value: FormatAmount.fiat(
                      order.payoutAmount,
                      order.payoutCurrency,
                    ),
                  ),
                  const Spacer(),
                  if (problem != null) ...[
                    Text(
                      problem,
                      style: context.bullType.body.copyWith(
                        color: context.appColors.error,
                      ),
                    ),
                    const Gap(16),
                  ],
                  BullButton.primary(
                    label: label,
                    onPressed: busy
                        ? null
                        : () => onEvent(const WithdrawConfirmPressed()),
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

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: context.bullType.body.copyWith(
            color: context.appColors.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            style: context.bullType.body.copyWith(
              color: context.appColors.secondary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Divider(color: context.appColors.secondaryFixedDim, height: 1);
}
