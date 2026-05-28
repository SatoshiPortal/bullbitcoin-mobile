import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dropdown/selectable_list.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/ui/widgets/selectable_custom_fee_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// Send-flow fee modal. On open, kicks off three unsigned-PSBT builds
/// (one per preset) and shows shimmer per row until each completes —
/// then renders the real `psbt.fee()` from BDK. No `rate × vsize`
/// math here.
class FeeOptionsModal extends StatefulWidget {
  const FeeOptionsModal({super.key});

  @override
  State<FeeOptionsModal> createState() => _FeeOptionsModalState();
}

class _FeeOptionsModalState extends State<FeeOptionsModal> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget — the cubit emits loading=true → unsigned PSBT
    // builds → real fee per preset → loading=false. The widget below
    // reacts via BlocSelector.
    context.read<SendCubit>().loadBitcoinFeePresetPreviews();
  }

  @override
  Widget build(BuildContext context) {
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
              const _PresetList(),
              const SelectableCustomFeeListItem(),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetList extends StatelessWidget {
  const _PresetList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SendCubit, SendState>(
      buildWhen: (prev, curr) =>
          prev.selectedFeeOption != curr.selectedFeeOption ||
          prev.feePreviewCache != curr.feePreviewCache ||
          prev.exchangeRate != curr.exchangeRate ||
          prev.fiatCurrencyCode != curr.fiatCurrencyCode,
      builder: (context, state) {
        final cache = state.feePreviewCache;
        final loading = cache.presetsLoading;
        // Titles MUST be FeeSelection.X.title() — the modal returns
        // them via Navigator.pop and the caller routes back through
        // FeeSelectionName.fromString. Localising the title would
        // break that round-trip until the lookup is keyed on the
        // enum instead (pre-existing l10n debt).
        final items = [
          _presetItem(
            title: FeeSelection.fastest.title(),
            description: context.loc.sendEstimatedDelivery10Minutes,
            rate: state.bitcoinFeesList?.fastest,
            previewFeeSat: cache.fastest.feeSat,
            loading: loading,
            exchangeRate: state.exchangeRate,
            fiatCurrencyCode: state.fiatCurrencyCode,
          ),
          _presetItem(
            title: FeeSelection.economic.title(),
            description: context.loc.sendEstimatedDelivery10to30Minutes,
            rate: state.bitcoinFeesList?.economic,
            previewFeeSat: cache.economic.feeSat,
            loading: loading,
            exchangeRate: state.exchangeRate,
            fiatCurrencyCode: state.fiatCurrencyCode,
          ),
          _presetItem(
            title: FeeSelection.slow.title(),
            description: context.loc.sendEstimatedDeliveryHours,
            rate: state.bitcoinFeesList?.slow,
            previewFeeSat: cache.slow.feeSat,
            loading: loading,
            exchangeRate: state.exchangeRate,
            fiatCurrencyCode: state.fiatCurrencyCode,
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

/// Builds one preset row. While `loading` and the preview hasn't
/// arrived yet, [SelectableListItem.isSubtitle2Loading] is true so
/// the row renders a shimmer instead of a `rate × vsize` string.
SelectableListItem _presetItem({
  required String title,
  required String description,
  required NetworkFee? rate,
  required int? previewFeeSat,
  required bool loading,
  required double exchangeRate,
  required String fiatCurrencyCode,
}) {
  // No rate yet (fees not loaded) → still placeholder.
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
    // Loading the unsigned PSBT for this preset — shimmer the fee.
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
