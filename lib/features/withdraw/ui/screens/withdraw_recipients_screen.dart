import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/recipients/public/recipients_ui.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_failure_l10n.dart';
import 'package:bb_mobile/features/withdraw/ui/withdraw_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WithdrawRecipientsScreen extends StatefulWidget {
  const WithdrawRecipientsScreen({super.key});

  @override
  State<WithdrawRecipientsScreen> createState() =>
      _WithdrawRecipientsScreenState();
}

class _WithdrawRecipientsScreenState extends State<WithdrawRecipientsScreen> {
  RecipientViewModel? _lastSelectedRecipient;
  String? _lastPaymentDescription;
  bool _lastSelectionWasNew = false;

  Future<void> _selectRecipient(
    BuildContext context,
    RecipientViewModel recipient, {
    required bool isNew,
  }) async {
    if (recipient.type == RecipientType.confidentialSepaEur &&
        !recipient.isVirtualPayeeActive) {
      _pushActivation(context, recipient, isNew: isNew);
      return;
    }

    String? paymentDescription;
    if (recipient.type.supportsPaymentDescription) {
      paymentDescription = await context.pushNamed<String>(
        WithdrawRoute.withdrawPaymentDescription.name,
        extra: _lastPaymentDescription,
      );
      if (!context.mounted || paymentDescription == null) return;
    }

    _lastSelectedRecipient = recipient;
    _lastPaymentDescription = paymentDescription;
    _lastSelectionWasNew = isNew;
    context.read<WithdrawBloc>().add(
      WithdrawEvent.recipientSelected(
        RecipientSelection.fromViewModel(recipient),
        isNew: isNew,
        paymentDescription: paymentDescription,
      ),
    );
  }

  void _pushActivation(
    BuildContext context,
    RecipientViewModel recipient, {
    required bool isNew,
  }) {
    context.pushNamed(
      WithdrawRoute.withdrawFrPayeeActivation.name,
      extra: FrPayeeActivationArgs(
        recipient: recipient,
        onActivated: (activated) =>
            _selectRecipient(context, activated, isNew: isNew),
        onUseRegularSepa: recipient.supportsRegularSepa
            ? () => _selectRecipient(
                context,
                recipient.copyWith(type: RecipientType.sepaEur),
                isNew: isNew,
              )
            : null,
      ),
    );
  }

  bool _confidentialSepaErrorAppeared(
    WithdrawState previous,
    WithdrawState current,
  ) {
    final currentError = current is WithdrawRecipientInputState
        ? current.selectedRecipientFailure ?? current.newRecipientFailure
        : null;
    final previousError = previous is WithdrawRecipientInputState
        ? previous.selectedRecipientFailure ?? previous.newRecipientFailure
        : null;
    return currentError is WithdrawConfidentialSepaNotActivatedFailure &&
        previousError is! WithdrawConfidentialSepaNotActivatedFailure;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WithdrawBloc, WithdrawState>(
      listenWhen: _confidentialSepaErrorAppeared,
      listener: (context, state) {
        final recipient = _lastSelectedRecipient;
        if (recipient == null) return;
        _pushActivation(context, recipient, isNew: _lastSelectionWasNew);
      },
      child: BlocBuilder<WithdrawBloc, WithdrawState>(
        bloc: context.read<WithdrawBloc>(),
        builder: (context, state) {
          return RecipientsScreen(
            filter: RecipientFilterCriteria(
              types: RecipientType.typesForCurrency(
                state.currency.code,
              ).toList(),
              isOwner: true,
            ),
            onRecipientSelected: (recipient, {required isNew}) async {
              await _selectRecipient(context, recipient, isNew: isNew);
            },
            isHookRunning: state is WithdrawRecipientInputState
                ? state.isCreatingWithdrawOrder
                : false,
            onRecipientAddedHookError: state is WithdrawRecipientInputState
                ? state.newRecipientFailure?.toTranslated(context)
                : null,
            onRecipientSelectedHookError: state is WithdrawRecipientInputState
                ? state.selectedRecipientFailure?.toTranslated(context)
                : null,
          );
        },
      ),
    );
  }
}
