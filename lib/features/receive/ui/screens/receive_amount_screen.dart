import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/labels/ui/label_entry_bottom_sheet.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_amount_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceiveAmountScreen extends StatefulWidget {
  const ReceiveAmountScreen({super.key, this.onContinueNavigation});

  final Function? onContinueNavigation;

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
    return BlocListener<ReceiveBloc, ReceiveState>(
      listenWhen: (previous, current) =>
          // Only listen on confirmed amount changes
          previous.confirmedAmountSat != current.confirmedAmountSat &&
          // Only listen when no amount exception is present
          current.amountException == null &&
          // Prevent using the amount from a previous receive type
          previous.type == current.type,
      listener: (context, state) {
        widget.onContinueNavigation?.call() ?? context.pop();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: .translucent,
        child: BBKeyboardActions(
          disableScroll: true,
          focusNodes: [_amountNode],
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              // Amount and message grouped together in the upper half, the
              // button pinned to the bottom — spaceEvenly scattered the
              // three elements across the full height with large voids.
              const Spacer(),
              ReceiveAmountInput(focusNode: _amountNode),
              const Gap(24),
              const _MessageForSenderTile(),
              const Spacer(flex: 2),
              ReceiveAmountContinueButton(
                onContinueNavigation: widget.onContinueNavigation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The counterparty-visible message: goes into the BIP21 `message=` (and the
/// lightning swap description).
class _MessageForSenderTile extends StatelessWidget {
  const _MessageForSenderTile();

  @override
  Widget build(BuildContext context) {
    final note = context.select((ReceiveBloc bloc) => bloc.state.note);
    final hPad = Device.screen.width * 0.04;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: BorderedTappableTile(
        onTap: () async {
          final bloc = context.read<ReceiveBloc>();
          final saved = await LabelEntryBottomSheet.note(
            context,
            title: context.loc.receiveMessageForSender,
            initialValue: note.isEmpty ? null : note,
            hint: context.loc.transactionNoteHint,
            suggestionsFuture: bloc.fetchDistinctLabels(),
          );
          if (saved == null) return;
          bloc.add(ReceiveNoteChanged(saved));
          // Persist as an address label too (same as the QR screen's note
          // flow) — without this, notes set from this page ended up in the
          // BIP21 string but never in the labels store.
          bloc.add(const ReceiveNoteSaved());
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText(
                    context.loc.receiveMessageForSender,
                    style: context.font.bodyLarge,
                    color: context.appColors.secondary,
                  ),
                  const Gap(4),
                  BBText(
                    note.isEmpty ? context.loc.receiveEnterHere : note,
                    style: context.font.bodyMedium,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, size: 20, color: context.appColors.secondary),
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
      // padding (not viewPadding): it is viewPadding minus the keyboard
      // inset, so it keeps the button off the home indicator when the
      // keyboard is closed and collapses to zero when the Scaffold has
      // already resized around the open keyboard — viewPadding would add a
      // second gap on top of the keyboard there.
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: BBButton.big(
        label: context.loc.receiveContinue,
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
        bgColor: context.appColors.secondary,
        textColor: context.appColors.onSecondary,
      ),
    );
  }
}
