import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendConfirmPage extends StatelessWidget {
  const SendConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select((ArkCubit cubit) => cubit.state.isLoading);
    final recipient = context.select(
      (ArkCubit cubit) => cubit.state.sendAddress?.address ?? '',
    );
    final amountSat = context.select((ArkCubit cubit) => cubit.state.amountSat);

    return Scaffold(
      appBar: AppBar(
        title: Text('Confirm Send', style: context.font.headlineMedium),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child:
              isLoading
                  ? FadingLinearProgress(
                    height: 3,
                    trigger: isLoading,
                    backgroundColor: context.colour.surface,
                    foregroundColor: context.colour.primary,
                  )
                  : const SizedBox(height: 3),
        ),
      ),
      body: SafeArea(
        child: ScrollableColumn(
          children: [
            Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  'Please confirm the details of your transaction before sending.',
                  style: context.font.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ListTile(
                  title: Text(
                    'Recipient Address',
                    style: context.font.bodyLarge,
                  ),
                  subtitle: Text(recipient, style: context.font.bodyMedium),
                ),
                ListTile(
                  title: Text('Amount (sats)', style: context.font.bodyLarge),
                  subtitle: Text(
                    amountSat.toString(),
                    style: context.font.bodyMedium,
                  ),
                ),
              ],
            ),
            const Spacer(),
            BBButton.big(
              label: 'Confirm',
              onPressed: () {
                context.read<ArkCubit>().onSendConfirmed();
              },
              disabled: isLoading,
              bgColor: context.colour.secondary,
              textColor: context.colour.onSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
