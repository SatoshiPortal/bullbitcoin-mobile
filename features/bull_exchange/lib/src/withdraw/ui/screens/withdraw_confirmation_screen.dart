import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:primitives/primitives.dart' show FormatAmount;
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/withdraw/presentation/withdraw_bloc.dart';
import 'package:bull_exchange/src/withdraw/presentation/withdraw_failure_l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullFadingLinearProgress,
        BullScrollableColumn,
        BullShimmerLine,
        Gap,
        BullTypographyX;

class WithdrawConfirmationScreen extends StatelessWidget {
  const WithdrawConfirmationScreen({required this.brandAsset, super.key});

  final String brandAsset;

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (WithdrawBloc bloc) => bloc.state is WithdrawConfirmationState
          ? (bloc.state as WithdrawConfirmationState).order
          : null,
    );

    final recipient = context.select(
      (WithdrawBloc bloc) => bloc.state is WithdrawConfirmationState
          ? (bloc.state as WithdrawConfirmationState).recipient
          : null,
    );

    final isConfirmOutcomeUnknown = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawConfirmationState &&
          (bloc.state as WithdrawConfirmationState).isConfirmOutcomeUnknown,
    );

    final screen = Scaffold(
      appBar: AppBar(title: Image.asset(brandAsset, height: 32, width: 32)),
      body: SafeArea(
        child: Column(
          children: [
            BullFadingLinearProgress(
              height: 3,
              trigger: context.select<WithdrawBloc, bool>(
                (bloc) =>
                    bloc.state is WithdrawConfirmationState &&
                    (bloc.state as WithdrawConfirmationState)
                        .isConfirmingWithdrawal,
              ),
              backgroundColor: context.appColors.onPrimary,
              foregroundColor: context.appColors.primary,
            ),
            Expanded(
              child: BullScrollableColumn(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                children: [
                  const Gap(24.0),
                  Text(
                    context.loc.withdrawConfirmTitle,
                    style: context.bullType.subtitle
                        .copyWith(fontWeight: FontWeight.w500)
                        .copyWith(color: context.appColors.secondary),
                  ),
                  const Gap(4.0),
                  const Gap(8.0),
                  _DetailRow(
                    title: context.loc.withdrawConfirmRecipientName,
                    value: recipient?.displayName,
                  ),
                  const _Divider(),
                  _DetailRow(
                    title:
                        recipient?.accountDetail(context).label ??
                        context.loc.withdrawConfirmBankAccount,
                    value: recipient?.accountDetail(context).value,
                  ),
                  const _Divider(),
                  _DetailRow(
                    title: context.loc.withdrawConfirmAmount,
                    value: order == null
                        ? null
                        : FormatAmount.fiat(
                            order.payoutAmount,
                            order.payoutCurrency,
                          ),
                  ),
                  const Spacer(),
                  _ConfirmButton(
                    onConfirmPressed: () {
                      context.read<WithdrawBloc>().add(
                        const WithdrawEvent.confirmed(),
                      );
                    },
                  ),
                  const Gap(24.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // Back to the recipients would let a second withdrawal be created while
    // the first may have gone through: leave the flow instead.
    return PopScope<Object?>(
      canPop: !isConfirmOutcomeUnknown,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isConfirmOutcomeUnknown) {
          BullExchangeNavigation.goToDashboard(context);
        }
      },
      child: screen,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String? value;

  const _DetailRow({required this.title, required this.value}) : super();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: value == null
          ? const BullShimmerLine()
          : Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text(
                  title,
                  style: context.bullType.body.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Text(
                    value!,
                    textAlign: .end,
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
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(color: context.appColors.secondaryFixedDim, height: 1);
  }
}

class _ConfirmButton extends StatelessWidget {
  final VoidCallback onConfirmPressed;

  const _ConfirmButton({required this.onConfirmPressed}) : super();

  @override
  Widget build(BuildContext context) {
    final isConfirmingWithdrawal = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawConfirmationState &&
          (bloc.state as WithdrawConfirmationState).isConfirmingWithdrawal,
    );
    final isConfirmOutcomeUnknown = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawConfirmationState &&
          (bloc.state as WithdrawConfirmationState).isConfirmOutcomeUnknown,
    );
    final withdrawFailure = context.select(
      (WithdrawBloc bloc) => bloc.state is WithdrawConfirmationState
          ? (bloc.state as WithdrawConfirmationState).failure
          : null,
    );

    return Column(
      children: [
        if (withdrawFailure != null) ...[
          Text(
            withdrawFailure.toTranslated(context),
            style: context.bullType.body.copyWith(
              color: context.appColors.error,
            ),
          ),
          const Gap(16),
        ],
        const Gap(16),
        if (isConfirmOutcomeUnknown)
          BullButton.primary(
            label: context.loc.withdrawConfirmCheckAgainButton,
            onPressed: isConfirmingWithdrawal
                ? null
                : () => context.read<WithdrawBloc>().add(
                    const WithdrawEvent.confirmOutcomeCheckRequested(),
                  ),
          )
        else
          BullButton.primary(
            label: context.loc.withdrawConfirmButton,
            onPressed: (isConfirmingWithdrawal) ? null : onConfirmPressed,
          ),
      ],
    );
  }
}
