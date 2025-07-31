import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class WithdrawConfirmationScreen extends StatelessWidget {
  const WithdrawConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawConfirmationState
              ? (bloc.state as WithdrawConfirmationState).order
              : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          Assets.logos.bbLogoSmall.path,
          height: 32,
          width: 32,
        ),
      ),
      body: SafeArea(
        child: ScrollableColumn(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          children: [
            const Gap(24.0),
            Text(
              'Confirm withdrawal',
              style: context.font.headlineMedium?.copyWith(
                color: context.colour.secondary,
              ),
            ),
            const Gap(4.0),
            const Gap(8.0),
            _DetailRow(
              title: 'Recipient name',
              value: order == null ? null : order.beneficiaryName ?? 'N/A',
            ),
            const _Divider(),
            _DetailRow(
              title: 'Bank account',
              value:
                  order == null
                      ? null
                      : order.beneficiaryAccountNumber ?? 'N/A',
            ),
            const _Divider(),
            _DetailRow(
              title: 'Amount',
              value:
                  order == null
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
      child:
          value == null
              ? const LoadingLineContent()
              : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.surfaceContainer,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.colour.outlineVariant,
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
    return Divider(color: context.colour.secondaryFixedDim, height: 1);
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
    final withdrawError = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawConfirmationState
              ? (bloc.state as WithdrawConfirmationState).error
              : null,
    );

    return Column(
      children: [
        if (isConfirmingWithdrawal) ...[
          const CircularProgressIndicator(),
          const Gap(24.0),
        ],
        if (withdrawError != null) ...[
          Text(
            'Error: $withdrawError',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.error,
            ),
          ),
          const Gap(16),
        ],
        const Gap(16),
        BBButton.big(
          label: 'Confirm withdrawal',
          disabled: isConfirmingWithdrawal,
          onPressed: onConfirmPressed,
          bgColor: context.colour.secondary,
          textColor: context.colour.onSecondary,
        ),
      ],
    );
  }
}
