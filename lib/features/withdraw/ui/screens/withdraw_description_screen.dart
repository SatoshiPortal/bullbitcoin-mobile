/*import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class WithdrawDescriptionScreen extends StatefulWidget {
  const WithdrawDescriptionScreen({super.key});

  @override
  State<WithdrawDescriptionScreen> createState() =>
      _WithdrawDescriptionScreenState();
}

class _WithdrawDescriptionScreenState extends State<WithdrawDescriptionScreen> {
  final TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment description')),
      body: SafeArea(
        child: ScrollableColumn(
          children: [
            const Gap(40.0),
            Text(
              'You can add an optional memo that the recipient will see in his bank account',
              style: context.font.labelMedium?.copyWith(color: Colors.black),
            ),
            const Gap(32.0),
            Text(
              'Memo for recipient (optional)',
              style: context.font.bodyMedium,
            ),
            const Gap(4.0),
            TextFormField(
              controller: _descriptionController,
              style: context.font.displaySmall?.copyWith(
                color: context.colour.primary,
              ),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
            const Spacer(),
            _ContinueButton(
              onContinuePressed: () {
                context.read<WithdrawBloc>().add(
                  WithdrawEvent.descriptionInputContinuePressed(
                    _descriptionController.text,
                  ),
                );
              },
            ),
            const Gap(24.0),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}

class _ContinueButton extends StatelessWidget {
  final VoidCallback onContinuePressed;

  const _ContinueButton({required this.onContinuePressed}) : super();

  @override
  Widget build(BuildContext context) {
    final isCreatingWithdrawOrder = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawDescriptionInputState &&
          (bloc.state as WithdrawDescriptionInputState).isCreatingWithdrawOrder,
    );
    final withdrawError = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawDescriptionInputState
              ? (bloc.state as WithdrawDescriptionInputState).error
              : null,
    );

    return Column(
      children: [
        if (isCreatingWithdrawOrder) ...[
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
          label: 'Continue',
          disabled: isCreatingWithdrawOrder,
          onPressed: onContinuePressed,
          bgColor: context.colour.secondary,
          textColor: context.colour.onSecondary,
        ),
      ],
    );
  }
}
*/
