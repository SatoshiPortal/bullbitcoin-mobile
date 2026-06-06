import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dropdown/selectable_list.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/ui/widgets/selectable_custom_fee_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FeeOptionsModal extends StatefulWidget {
  const FeeOptionsModal({super.key});

  @override
  State<FeeOptionsModal> createState() => _FeeOptionsModalState();
}

class _FeeOptionsModalState extends State<FeeOptionsModal> {
  final _customFeeNode = FocusNode();

  @override
  void dispose() {
    _customFeeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedFeeOption = context.read<SendCubit>().state.selectedFeeOption;
    final feeList = context.read<SendCubit>().state.bitcoinFeesList!;
    final fees = feeList.display(
      context.read<SendCubit>().state.bitcoinTxSize ?? 140,
      context.read<SendCubit>().state.exchangeRate,
      context.read<SendCubit>().state.fiatCurrencyCode,
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
        child: BBKeyboardActions(
          isDialog: true,
          focusNodes: [_customFeeNode],
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              const Gap(16),
              BBText(
                context.loc.sendSelectNetworkFee,
                style: context.font.headlineMedium,
              ),
              const Gap(16),
              SelectableList(
                selectedValue: selectedFeeOption.title(),
                items: feeOptions,
              ),
              SelectableCustomFeeListItem(focusNode: _customFeeNode),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }
}
