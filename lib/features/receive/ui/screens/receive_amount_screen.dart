import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_amount_entry.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_numberpad.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveAmountScreen extends StatelessWidget {
  const ReceiveAmountScreen({super.key, this.onContinueNavigation});

  final Function? onContinueNavigation;

  @override
  Widget build(BuildContext context) {
    return AmountPage(onContinueNavigation: onContinueNavigation);
  }
}

class AmountPage extends StatelessWidget {
  const AmountPage({
    super.key,
    this.onContinueNavigation,
  });

  final Function? onContinueNavigation;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ReceiveAmountEntry(),
          const ReceiveNumberPad(),
          ReceiveAmountContinueButton(
            onContinueNavigation: onContinueNavigation,
          ),
        ],
      ),
    );
  }
}

class ReceiveAmountContinueButton extends StatelessWidget {
  const ReceiveAmountContinueButton({
    super.key,
    this.onContinueNavigation,
  });

  final Function? onContinueNavigation;

  @override
  Widget build(BuildContext context) {
    final creatingSwap = context.watch<ReceiveBloc>().state.creatingSwap;
    final swapAmountBelowLimit =
        context.watch<ReceiveBloc>().state.swapAmountBelowLimit;
    final swapAmountAboveLimit =
        context.watch<ReceiveBloc>().state.swapAmountAboveLimit;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BBButton.big(
        label: 'Continue',
        onPressed: () {
          // Confirm the amount and continue

          context.read<ReceiveBloc>().add(const ReceiveAmountConfirmed());
          Future.delayed(const Duration(milliseconds: 100));
          // Continue navigation can be different depending on the context.
          // For example when the amount screen is the first screen in the flow
          // as with Lightning or not.
          if (onContinueNavigation != null &&
              (!swapAmountAboveLimit && !swapAmountBelowLimit)) {
            onContinueNavigation!();
          } else {
            // context.pop();
          }
        },
        disabled: creatingSwap,
        bgColor: context.colour.secondary,
        textColor: context.colour.onSecondary,
      ),
    );
  }
}
