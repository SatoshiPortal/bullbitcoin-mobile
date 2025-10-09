import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_amount_entry.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_numberpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ReceiveAmountScreen extends StatelessWidget {
  const ReceiveAmountScreen({super.key, this.onContinueNavigation});

  final Function? onContinueNavigation;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReceiveBloc, ReceiveState>(
      listenWhen:
          (previous, current) =>
              // Only listen on confirmed amount changes
              previous.confirmedAmountSat != current.confirmedAmountSat &&
              // Only listen when no amount exception is present
              current.amountException == null &&
              // Prevent using the amount from a previous receive type
              previous.type == current.type,
      listener: (context, state) {
        onContinueNavigation?.call() ?? context.pop();
      },
      child: AmountPage(onContinueNavigation: onContinueNavigation),
    );
  }
}

class AmountPage extends StatefulWidget {
  const AmountPage({super.key, this.onContinueNavigation});

  final Function? onContinueNavigation;

  @override
  State<AmountPage> createState() => _AmountPageState();
}

class _AmountPageState extends State<AmountPage> {
  late TextEditingController _amountController;
  late FocusNode _amountFocusNode;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ReceiveBloc>();
    final initialAmount = bloc.state.inputAmount;
    _amountController = TextEditingController.fromValue(
      TextEditingValue(text: initialAmount),
    );
    _amountController.addListener(() {
      final text = _amountController.text;
      if (text != bloc.state.inputAmount) {
        bloc.add(ReceiveEvent.receiveAmountInputChanged(text));
      }
    });
    _amountFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReceiveBloc, ReceiveState>(
      listenWhen:
          (previous, current) =>
              previous.inputAmountCurrencyCode !=
              current.inputAmountCurrencyCode,
      listener: (context, state) {
        // Clear the controller when currency changes
        _amountController.clear();
      },
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.translucent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReceiveAmountEntry(
              amountController: _amountController,
              focusNode: _amountFocusNode,
            ),
            ReceiveNumberPad(amountController: _amountController),
            ReceiveAmountContinueButton(
              onContinueNavigation: widget.onContinueNavigation,
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiveAmountContinueButton extends StatelessWidget {
  const ReceiveAmountContinueButton({super.key, this.onContinueNavigation});

  final Function? onContinueNavigation;

  @override
  Widget build(BuildContext context) {
    final creatingSwap = context.watch<ReceiveBloc>().state.creatingSwap;
    final amountException = context.watch<ReceiveBloc>().state.amountException;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BBButton.big(
        label: 'Continue',
        onPressed: () {
          final bloc = context.read<ReceiveBloc>();
          final inputAmountSat = bloc.state.inputAmountSat;
          final confirmedAmountSat = bloc.state.confirmedAmountSat;
          if (confirmedAmountSat != null &&
              inputAmountSat == confirmedAmountSat) {
            // If an amount was already confirmed previously and the user didn't
            // change it, we don't need to confirm it again.
            onContinueNavigation?.call() ?? context.pop();
          } else {
            bloc.add(const ReceiveAmountConfirmed());
          }
        },
        disabled: creatingSwap || amountException != null,
        bgColor: context.colour.secondary,
        textColor: context.colour.onSecondary,
      ),
    );
  }
}
