import 'package:receive/src/ui/receive_localizations.dart';
import 'package:receive/receive.dart';
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:receive/src/presentation/receive_failure_l10n.dart';

import 'payjoin_disclaimer_dialog.dart';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The global Payjoin setting, preserving eligibility and the enable disclaimer.
class ReceivePayjoinToggleTile extends StatelessWidget {
  const ReceivePayjoinToggleTile({super.key, required this.topGap});
  final double topGap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    if (state.type != ReceiveType.bitcoin ||
        state.wallet?.signsLocally != true) {
      return const SizedBox.shrink();
    }
    final subtitle = switch (state.advancedOptions.payjoinExplanation) {
      ReceivePayjoinExplanation.awaitingFunds =>
        context.loc.receivePayjoinStartsWithFunds,
      ReceivePayjoinExplanation.belowMinimum =>
        context.loc.receivePayjoinNotUsedForAmount,
      ReceivePayjoinExplanation.global =>
        context.loc.receivePayjoinAppliesGlobally,
    };
    return BlocListener<ReceiveBloc, ReceiveState>(
      listenWhen: (previous, current) =>
          current.failure is ReceivePayjoinSettingFailure &&
          previous.failure != current.failure,
      listener: (context, next) {
        if (next.failure case final failure?) {
          BullSnackBar.show(context, message: failure.toTranslated(context));
        }
      },
      child: Padding(
        padding: EdgeInsets.only(top: topGap),
        child: BullSettingsEntryItem(
          icon: BullIcons.privacy,
          contentPadding: EdgeInsets.zero,
          title: context.loc.receivePayjoinQrBadge,
          subtitle: subtitle,
          trailing: SizedBox(
            width: 52,
            height: 48,
            child: BullSwitch(
              value: state.payjoinGloballyEnabled ?? false,
              onChanged: !state.isPayjoinToggleable
                  ? null
                  : (value) {
                      context.read<ReceiveBloc>().add(
                        ReceivePayjoinToggled(value, () async {
                          if (!context.mounted) return false;
                          return PayjoinDisclaimerDialog.show(context);
                        }),
                      );
                    },
            ),
          ),
        ),
      ),
    );
  }
}
