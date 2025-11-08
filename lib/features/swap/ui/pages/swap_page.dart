import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_amount_input.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_balance_row.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_from_wallet_dropdown.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_to_wallet_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SwapPage extends StatefulWidget {
  const SwapPage({super.key});
  @override
  _SwapPageState createState() => _SwapPageState();
}

class _SwapPageState extends State<SwapPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  int _amountSat = 0;

  @override
  void initState() {
    super.initState();
    final bitcoinUnit = context.read<TransferBloc>().state.bitcoinUnit;
    _amountController.addListener(() {
      // Keep the amount in satoshis updated so we can use it elsewhere to
      // calculate fees etc. in Stateless child Widgets like SwapAmountInput
      // and SwapFeesRow.
      setState(() {
        _amountSat =
            bitcoinUnit == BitcoinUnit.sats
                ? int.tryParse(_amountController.text) ?? 0
                : ConvertAmount.btcToSats(
                  double.tryParse(_amountController.text) ?? 0,
                );
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Internal Transfer'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BlocSelector<TransferBloc, TransferState, bool>(
            selector: (state) => state.isStarting || state.isCreatingSwap,
            builder:
                (context, isLoading) => FadingLinearProgress(
                  height: 3,
                  trigger: isLoading,
                  backgroundColor: context.colour.onPrimary,
                  foregroundColor: context.colour.primary,
                ),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ScrollableColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const Gap(12),
              InfoCard(
                description:
                    'Transfer Bitcoin seamlessly between your wallets. Only keep funds in the Instant Payment Wallet for day-to-day spending.',
                tagColor: context.colour.inverseSurface,
                bgColor: context.colour.inverseSurface.withValues(alpha: 0.1),
              ),
              const Gap(12),
              const SwapFromWalletDropdown(),
              const Gap(12),
              const SwapToWalletDropdown(),
              const Gap(12),
              SwapAmountInput(
                amountController: _amountController,
                amountSat: _amountSat,
              ),
              const Gap(12),
              SwapBalanceRow(amountController: _amountController),
              const Gap(12),
              BlocSelector<TransferBloc, TransferState, SwapCreationException?>(
                selector: (state) => state.swapCreationException,
                builder: (context, swapCreationError) {
                  return Text(
                    swapCreationError?.message ?? '',
                    style: context.font.labelLarge?.copyWith(
                      color: context.colour.error,
                    ),
                    maxLines: 4,
                  );
                },
              ),
              const Gap(24),
              const Spacer(),
              BlocSelector<TransferBloc, TransferState, bool>(
                selector: (state) => state.isStarting || state.isCreatingSwap,
                builder: (context, isLoading) {
                  return BBButton.big(
                    label: 'Continue',
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onSecondary,
                    disabled: isLoading,
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) {
                        return;
                      }
                      context.read<TransferBloc>().add(
                        TransferEvent.swapCreated(_amountController.text),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
