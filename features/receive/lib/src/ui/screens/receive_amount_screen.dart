import 'package:intl/intl.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:receive/src/ui/receive_localizations.dart';
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:receive/src/presentation/receive_failure_l10n.dart';
import 'package:receive/src/presentation/receive_navigation.dart';
import 'package:receive/src/ui/widgets/receive_amount_input.dart';
import 'package:receive/src/ui/widgets/receive_advanced_settings.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ReceiveAmountScreen extends StatefulWidget {
  const ReceiveAmountScreen({
    super.key,
    this.onContinueNavigation,
    this.openPayjoinSettings,
  });
  final Function? onContinueNavigation;
  final void Function(BuildContext)? openPayjoinSettings;

  @override
  State<ReceiveAmountScreen> createState() => _ReceiveAmountScreenState();
}

class _ReceiveAmountScreenState extends State<ReceiveAmountScreen> {
  final _amountNode = FocusNode();

  @override
  void dispose() {
    _amountNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    final limits = state.swapLimits;
    final numbers = NumberFormat.decimalPattern(context.loc.localeName);
    final showLimits = state.lightningLimits.requiresBounds && limits != null;
    final outsideLimits =
        state.isInputAmountBelowLimit || state.isInputAmountAboveLimit;
    final failure =
        state.admissionFailure ??
        (state.hasAmountInputFailure ? null : state.failure);
    return BlocListener<ReceiveBloc, ReceiveState>(
      listenWhen: (previous, current) =>
          previous.type == current.type &&
          current.canConfirmAmount &&
          ((previous.creatingSwap &&
                  !current.creatingSwap &&
                  current.getSwap != null &&
                  current.failure == null) ||
              (current.type != ReceiveType.lightning &&
                  (previous.confirmedAmountSat != current.confirmedAmountSat ||
                      previous.confirmedConversion !=
                          current.confirmedConversion))),
      listener: (context, state) {
        widget.onContinueNavigation?.call() ?? context.pop();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.loc.amountLabel, style: context.bullType.body),
                  const Gap(6),
                  ReceiveAmountInput(focusNode: _amountNode, inCard: true),
                  const Gap(12),
                  if (showLimits)
                    Text(
                      context.loc.receiveLimits(
                        numbers.format(limits.min),
                        numbers.format(limits.max),
                      ),
                      style: context.bullType.label.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  if (showLimits &&
                      state.amountEntryValid &&
                      !state.hasAmountInputFailure &&
                      state.inputAmount.isNotEmpty &&
                      outsideLimits)
                    Text(
                      state.isInputAmountBelowLimit
                          ? context.loc.receiveBelowMinimum(
                              numbers.format(limits.min),
                            )
                          : context.loc.receiveAboveMaximum(
                              numbers.format(limits.max),
                            ),
                      style: context.bullType.label.copyWith(
                        color: context.appColors.error,
                      ),
                    ),
                  if (state.wallet?.isLiquid == true) ...[
                    const Gap(12),
                    Text(
                      context.loc.receiveArrivesAsLiquid,
                      style: context.bullType.label.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                  if (failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        failure.toTranslated(context),
                        style: context.bullType.body.copyWith(
                          color: context.appColors.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ReceiveAdvancedSettingsLink(
              openPayjoinSettings: widget.openPayjoinSettings,
            ),
          ),
          ReceiveAmountContinueButton(
            onContinueNavigation: widget.onContinueNavigation,
          ),
        ],
      ),
    );
  }
}

class ReceiveAmountContinueButton extends StatelessWidget {
  const ReceiveAmountContinueButton({super.key, this.onContinueNavigation});
  final Function? onContinueNavigation;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    final valid = state.isLightning
        ? state.canCreateInvoice
        : state.canConfirmAmount;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BullButton.primary(
              label: state.creatingSwap
                  ? context.loc.receiveCreatingInvoice
                  : state.isLightning
                  ? context.loc.receiveCreateInvoice
                  : context.loc.receiveContinue,
              onPressed:
                  !valid || state.creatingSwap || state.hasAmountInputFailure
                  ? null
                  : () {
                      final bloc = context.read<ReceiveBloc>();
                      if (canReuseConfirmedReceiveDetails(bloc.state)) {
                        onContinueNavigation?.call() ?? context.pop();
                      } else {
                        bloc.add(const ReceiveAmountConfirmed());
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
