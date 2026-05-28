import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/fees/custom_fee_list_item.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Send-flow wrapper around [CustomFeeListItem]. Binds the shared widget
/// to [SendCubit]: typing fires the cubit's preview path (unsigned PSBT
/// build → real `psbt.fee()`), modal dismissal triggers the full commit.
class SelectableCustomFeeListItem extends StatefulWidget {
  const SelectableCustomFeeListItem({super.key});

  @override
  State<SelectableCustomFeeListItem> createState() =>
      _SelectableCustomFeeListItemState();
}

class _SelectableCustomFeeListItemState
    extends State<SelectableCustomFeeListItem> {
  late SendCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<SendCubit>();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SendCubit, SendState>(
      buildWhen: (prev, curr) =>
          prev.customFee != curr.customFee ||
          prev.selectedFeeOption != curr.selectedFeeOption ||
          prev.feeOptions != curr.feeOptions ||
          prev.bitcoinTxSize != curr.bitcoinTxSize ||
          prev.exchangeRate != curr.exchangeRate ||
          prev.fiatCurrencyCode != curr.fiatCurrencyCode ||
          prev.feePreviewCache.custom != curr.feePreviewCache.custom ||
          prev.feePreviewCache.customLoading !=
              curr.feePreviewCache.customLoading,
      builder: (context, state) {
        final customSlot = state.feePreviewCache.custom;
        return CustomFeeListItem(
          initialFee: state.customFee,
          isCommittedAsCustom: state.selectedFeeOption == FeeSelection.custom,
          feePresets: state.feeOptions,
          txSize: state.bitcoinTxSize ?? 140,
          exchangeRate: state.exchangeRate,
          fiatCurrencyCode: state.fiatCurrencyCode,
          defaultAbsolute: false,
          tileColor: context.appColors.surface,
          tileShadowColor: context.appColors.border,
          unselectedIconColor: context.appColors.textMuted,
          // Real fee from a debounced unsigned-PSBT build. Null while
          // the build is in flight (or user hasn't typed yet) — widget
          // renders shimmer when previewLoading is true.
          previewFeeSat: customSlot.feeSat,
          previewLoading: state.feePreviewCache.customLoading,
          onArm: _cubit.armCustomFee,
          onPreview: _cubit.previewBitcoinCustomFee,
          // Modal mode: onCommit is unused at the widget level — the
          // parent (send_screen) runs finalizeArmedCustomFee on
          // dismissal, which calls customFeesChanged.
          onCommit: (_) async {},
        );
      },
    );
  }
}
