import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/receive/ui/widgets/receive_amount_entry.dart';
import 'package:bb_mobile/receive/ui/widgets/receive_network_selection.dart';
import 'package:bb_mobile/receive/ui/widgets/receive_numberpad.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceiveAmountScreen extends StatelessWidget {
  const ReceiveAmountScreen({
    super.key,
    this.onContinuePressed,
  });

  final Function? onContinuePressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Receive',
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(AppRoute.home.name);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: AmountPage(
          onContinuePressed: onContinuePressed,
        ),
        // child: AmountPage(),
      ),
    );
  }
}

class AmountPage extends StatelessWidget {
  const AmountPage({
    super.key,
    this.onContinuePressed,
  });

  final Function? onContinuePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(10),
        const ReceiveNetworkSelection(),
        const Gap(82),
        const ReceiveAmountEntry(),
        const Gap(82),
        const ReceiveNumberPad(),
        const Gap(40),
        ReceiveAmountContinueButton(
          onPressed: onContinuePressed,
        ),
        const Gap(40),
      ],
    );
  }
}

class ReceiveAmountContinueButton extends StatelessWidget {
  const ReceiveAmountContinueButton({
    super.key,
    this.onPressed,
  });

  final Function? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BBButton.big(
        label: 'Continue',
        onPressed: onPressed ?? context.pop,
        disabled: !context.watch<ReceiveBloc>().state.hasAmount,
        bgColor: context.colour.secondary,
        textColor: context.colour.onSecondary,
      ),
    );
  }
}
