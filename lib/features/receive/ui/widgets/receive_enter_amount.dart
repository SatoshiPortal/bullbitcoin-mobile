import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_amount_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Bottom-sheet variant of the amount editor used by the receive QR screen.
///
/// Mirrors [LabelEntryBottomSheet] so amount edits don't push a new route — that
/// avoids the auto-redirect to transaction details that fires when the
/// already-revealed receive address has historical txs.
class ReceiveEnterAmount extends StatelessWidget {
  const ReceiveEnterAmount({super.key});

  static Future<void> showBottomSheet(BuildContext context) async {
    final bloc = context.read<ReceiveBloc>();
    await BlurredBottomSheet.show(
      context: context,
      child: BlocProvider.value(
        value: bloc,
        child: const ReceiveEnterAmount(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReceiveBloc, ReceiveState>(
      listenWhen: (previous, current) =>
          previous.confirmedAmountSat != current.confirmedAmountSat &&
          current.amountException == null &&
          previous.type == current.type,
      listener: (context, state) => context.pop(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(22),
            Row(
              children: [
                const Gap(22),
                const Spacer(),
                BBText(
                  context.loc.receiveAmount,
                  style: context.font.headlineMedium,
                  color: context.appColors.secondary,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.pop(),
                  color: context.appColors.secondary,
                  icon: const Icon(Icons.close_sharp),
                ),
              ],
            ),
            const Gap(24),
            const BorderedTappableTile(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: ReceiveAmountEntry(),
            ),
            const Gap(24),
            const _ConfirmButton(),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton();

  @override
  Widget build(BuildContext context) {
    final amountException = context.select(
      (ReceiveBloc bloc) => bloc.state.amountException,
    );
    return BBButton.big(
      label: context.loc.receiveContinue,
      onPressed: () {
        final bloc = context.read<ReceiveBloc>();
        final inputAmountSat = bloc.state.inputAmountSat;
        final confirmedAmountSat = bloc.state.confirmedAmountSat;
        if (confirmedAmountSat != null &&
            inputAmountSat == confirmedAmountSat) {
          // No change — just close.
          context.pop();
        } else {
          bloc.add(const ReceiveAmountConfirmed());
        }
      },
      disabled: amountException != null,
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onSecondary,
    );
  }
}
