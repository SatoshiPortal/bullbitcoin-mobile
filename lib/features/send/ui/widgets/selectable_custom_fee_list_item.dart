import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/fees/custom_fee_list_item.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Send-flow wrapper around [CustomFeeListItem] — binds the shared widget to
/// the [SendCubit]. The widget owns the local edit state; this binding lifts
/// commits to the cubit and provides theme tokens specific to the send modal.
class SelectableCustomFeeListItem extends StatefulWidget {
  const SelectableCustomFeeListItem({super.key});

  @override
  State<SelectableCustomFeeListItem> createState() =>
      _SelectableCustomFeeListItemState();
}

class _SelectableCustomFeeListItemState
    extends State<SelectableCustomFeeListItem> {
  // Hold the cubit ref so `onDisarm` can fire during dispose, when reading
  // it from context would be unsafe.
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
          prev.bitcoinAbsoluteFeesSat != curr.bitcoinAbsoluteFeesSat,
      builder: (context, state) {
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
          // Real fee from the last built PSBT — armCustomFee nulls this on
          // first keystroke, so the modal preview tracks the prediction
          // during editing and only shows the real value when the typed
          // input matches the currently committed customFee.
          committedAbsoluteFeesSat: state.bitcoinAbsoluteFeesSat,
          onArm: _cubit.armCustomFee,
          // Modal mode never invokes onCommit from the widget — the
          // parent (send_screen) calls finalizeArmedCustomFee on
          // modal dismissal. Passing a no-op satisfies the required
          // parameter without coupling the widget to commit logic
          // that isn't its job.
          onCommit: (_) async {},
        );
      },
    );
  }
}
