import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dropdown/selectable_list.dart';
import 'package:bb_mobile/core/widgets/fees/custom_fee_list_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SwapFeeOptionsModal extends StatelessWidget {
  const SwapFeeOptionsModal({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TransferBloc>();
    final state = bloc.state;
    final feeList = state.bitcoinNetworkFees;
    if (feeList == null) return const SizedBox.shrink();

    final fees = feeList.display(
      state.bitcoinTxSize ?? 140,
      state.exchangeRate ?? 0.0,
      state.fiatCurrencyCode ?? 'CAD',
    );
    final List<SelectableListItem> feeOptions = [
      for (final fee in fees)
        SelectableListItem(
          value: fee.$1,
          title: fee.$1,
          subtitle1: fee.$2,
          subtitle2: fee.$3,
        ),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              const Gap(16),
              BBText(
                context.loc.sendSelectNetworkFee,
                style: context.font.headlineMedium,
              ),
              const Gap(16),
              Builder(
                builder: (context) => SelectableList(
                  selectedValue: state.selectedFeeOption.title(),
                  items: feeOptions,
                ),
              ),
              SwapSelectableCustomFeeListItem(bloc: bloc),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Swap-flow wrapper around [CustomFeeListItem] — binds the shared widget to
/// the [TransferBloc] via events. Parallels [SelectableCustomFeeListItem] on
/// the send side; differences are only in the theme tokens and the
/// event-vs-method shape of the underlying state container.
class SwapSelectableCustomFeeListItem extends StatefulWidget {
  const SwapSelectableCustomFeeListItem({super.key, required this.bloc});

  final TransferBloc bloc;

  @override
  State<SwapSelectableCustomFeeListItem> createState() =>
      _SwapSelectableCustomFeeListItemState();
}

class _SwapSelectableCustomFeeListItemState
    extends State<SwapSelectableCustomFeeListItem> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferBloc, TransferState>(
      bloc: widget.bloc,
      buildWhen: (prev, curr) =>
          prev.customFee != curr.customFee ||
          prev.selectedFeeOption != curr.selectedFeeOption ||
          prev.bitcoinNetworkFees != curr.bitcoinNetworkFees ||
          prev.bitcoinTxSize != curr.bitcoinTxSize ||
          prev.exchangeRate != curr.exchangeRate ||
          prev.fiatCurrencyCode != curr.fiatCurrencyCode,
      builder: (context, state) {
        return CustomFeeListItem(
          initialFee: state.customFee,
          isCommittedAsCustom: state.selectedFeeOption == FeeSelection.custom,
          feePresets: state.bitcoinNetworkFees,
          txSize: state.bitcoinTxSize ?? 140,
          exchangeRate: state.exchangeRate ?? 0.0,
          fiatCurrencyCode: state.fiatCurrencyCode ?? 'CAD',
          defaultAbsolute: true,
          tileColor: context.appColors.onSecondary,
          tileShadowColor: context.appColors.secondary,
          unselectedIconColor: context.appColors.surface,
          onArm: (fee) =>
              widget.bloc.add(TransferEvent.customFeeArmed(fee)),
          onCommit: (fee) async {
            widget.bloc.add(TransferEvent.customFeeChanged(fee));
          },
          onDisarm: () =>
              widget.bloc.add(const TransferEvent.customFeeDisarmed()),
          onConfirmed: () =>
              Navigator.pop(context, context.loc.sendCustomFee),
        );
      },
    );
  }
}
