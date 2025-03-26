import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/receive/ui/widgets/receive_amount_entry.dart';
import 'package:bb_mobile/receive/ui/widgets/receive_numberpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceiveAmountScreen extends StatelessWidget {
  const ReceiveAmountScreen({super.key, this.onContinueNavigation});

  final Function? onContinueNavigation;

  @override
  Widget build(BuildContext context) {
    // return Scaffold(
    //   appBar: AppBar(
    //     forceMaterialTransparency: true,
    //     automaticallyImplyLeading: false,
    //     flexibleSpace: TopBar(
    //       title: 'Receive',
    //       onBack: () {
    //         if (context.canPop()) {
    //           context.pop();
    //         } else {
    //           context.goNamed(AppRoute.home.name);
    //         }
    //       },
    //     ),
    //   ),
    //   body: SingleChildScrollView(
    //     child: AmountPage(onContinueNavigation: onContinueNavigation),
    //     // child: AmountPage(),
    //   ),
    // );

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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // const Gap(10),
          // const ReceiveNetworkSelection(),
          const Gap(82),
          const ReceiveAmountEntry(),
          const Gap(82),
          const ReceiveNumberPad(),
          const Gap(40),
          ReceiveAmountContinueButton(
            onContinueNavigation: onContinueNavigation,
          ),
          const Gap(40),
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BBButton.big(
        label: 'Continue',
        onPressed: () {
          // Confirm the amount and continue
          context.read<ReceiveBloc>().add(const ReceiveAmountConfirmed());

          // Continue navigation can be different depending on the context.
          // For example when the amount screen is the first screen in the flow
          // as with Lightning or not.
          if (onContinueNavigation != null) {
            onContinueNavigation!();
          } else {
            context.pop();
          }
        },
        disabled: context.watch<ReceiveBloc>().state.inputAmount.isEmpty,
        bgColor: context.colour.secondary,
        textColor: context.colour.onSecondary,
      ),
    );
  }
}
