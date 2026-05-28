import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dropdown/selectable_list.dart';
import 'package:bb_mobile/core/widgets/fees/custom_fee_list_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// Swap-flow fee modal. Parallels `FeeOptionsModal` on the send side.
/// On open, dispatches a preset-preview build via the bloc; each preset
/// row shimmers until its real `psbt.fee()` arrives. No naive math.
class SwapFeeOptionsModal extends StatefulWidget {
  const SwapFeeOptionsModal({super.key});

  @override
  State<SwapFeeOptionsModal> createState() => _SwapFeeOptionsModalState();
}

class _SwapFeeOptionsModalState extends State<SwapFeeOptionsModal> {
  late TransferBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<TransferBloc>();
    _bloc.add(const TransferEvent.presetFeesPreviewRequested());
  }

  @override
  Widget build(BuildContext context) {
    final state = _bloc.state;
    final feeList = state.bitcoinNetworkFees;
    if (feeList == null) return const SizedBox.shrink();

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
              _SwapPresetList(bloc: _bloc),
              SwapSelectableCustomFeeListItem(bloc: _bloc),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwapPresetList extends StatelessWidget {
  const _SwapPresetList({required this.bloc});

  final TransferBloc bloc;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferBloc, TransferState>(
      bloc: bloc,
      buildWhen: (prev, curr) =>
          prev.selectedFeeOption != curr.selectedFeeOption ||
          prev.feePreviewCache != curr.feePreviewCache ||
          prev.exchangeRate != curr.exchangeRate ||
          prev.fiatCurrencyCode != curr.fiatCurrencyCode,
      builder: (context, state) {
        final cache = state.feePreviewCache;
        final loading = cache.presetsLoading;
        final exchangeRate = state.exchangeRate ?? 0.0;
        final currency = state.fiatCurrencyCode ?? 'CAD';
        // See FeeOptionsModal for the identical pattern. Titles MUST
        // be FeeSelection.X.title() — modal returns them via pop and
        // the caller routes back through FeeSelectionName.fromString.
        final items = [
          _swapPresetItem(
            title: FeeSelection.fastest.title(),
            description: context.loc.sendEstimatedDelivery10Minutes,
            rate: state.bitcoinNetworkFees?.fastest,
            previewFeeSat: cache.fastest.feeSat,
            loading: loading,
            exchangeRate: exchangeRate,
            fiatCurrencyCode: currency,
          ),
          _swapPresetItem(
            title: FeeSelection.economic.title(),
            description: context.loc.sendEstimatedDelivery10to30Minutes,
            rate: state.bitcoinNetworkFees?.economic,
            previewFeeSat: cache.economic.feeSat,
            loading: loading,
            exchangeRate: exchangeRate,
            fiatCurrencyCode: currency,
          ),
          _swapPresetItem(
            title: FeeSelection.slow.title(),
            description: context.loc.sendEstimatedDeliveryHours,
            rate: state.bitcoinNetworkFees?.slow,
            previewFeeSat: cache.slow.feeSat,
            loading: loading,
            exchangeRate: exchangeRate,
            fiatCurrencyCode: currency,
          ),
        ];
        return SelectableList(
          selectedValue: state.selectedFeeOption.title(),
          items: items,
        );
      },
    );
  }
}

SelectableListItem _swapPresetItem({
  required String title,
  required String description,
  required NetworkFee? rate,
  required int? previewFeeSat,
  required bool loading,
  required double exchangeRate,
  required String fiatCurrencyCode,
}) {
  if (rate == null) {
    return SelectableListItem(
      value: title,
      title: title,
      subtitle1: description,
      subtitle2: '',
      isSubtitle2Loading: true,
    );
  }
  final rateLabel = '${rate.value} sats/vB';
  if (previewFeeSat == null) {
    return SelectableListItem(
      value: title,
      title: title,
      subtitle1: description,
      subtitle2: rateLabel,
      isSubtitle2Loading: true,
    );
  }
  final fiatPart = exchangeRate > 0 && fiatCurrencyCode.isNotEmpty
      ? ' (~ ${ConvertAmount.satsToFiat(previewFeeSat, exchangeRate)} '
            '$fiatCurrencyCode)'
      : '';
  return SelectableListItem(
    value: title,
    title: title,
    subtitle1: description,
    subtitle2:
        '$rateLabel ~ ${FormatAmount.satsApprox(previewFeeSat)} sats$fiatPart',
  );
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
          prev.fiatCurrencyCode != curr.fiatCurrencyCode ||
          prev.feePreviewCache.custom != curr.feePreviewCache.custom ||
          prev.feePreviewCache.customLoading !=
              curr.feePreviewCache.customLoading,
      builder: (context, state) {
        final customSlot = state.feePreviewCache.custom;
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
          previewFeeSat: customSlot.feeSat,
          previewLoading: state.feePreviewCache.customLoading,
          onArm: (fee) =>
              widget.bloc.add(TransferEvent.customFeeArmed(fee)),
          onPreview: (fee) => widget.bloc.add(
            TransferEvent.customFeePreviewRequested(fee),
          ),
          // Modal mode: onCommit unused at the widget level. Parent
          // (swap_confirm_page) runs customFeeFinalized on dismissal.
          onCommit: (_) async {},
        );
      },
    );
  }
}
