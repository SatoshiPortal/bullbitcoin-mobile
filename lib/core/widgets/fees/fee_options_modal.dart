import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dropdown/selectable_list.dart';
import 'package:bb_mobile/core/widgets/fees/custom_fee_list_item.dart';
import 'package:bb_mobile/core/widgets/fees/fee_modal_controller.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

/// Shared fee-selection bottom sheet — mounted by both the Bitcoin send
/// confirm screen and the swap confirm page. The widget depends only on
/// [FeeModalViewState] (state slice) and [FeeModalActions] (dispatch),
/// so it has no knowledge of the underlying `SendCubit` / `TransferBloc`
/// shapes. Each caller supplies its own concrete adapter — the shared
/// cubits already `implements` both ports.
///
/// On open, the modal fires [FeeModalActions.requestPresetPreviews] so
/// every tile gets its real `psbt.fee()` from an unsigned PSBT build.
/// While that's in flight the rows shimmer. Custom-fee typing is
/// debounced inside [CustomFeeListItem]; the value persists across
/// reopen because the controller's snapshot stream carries
/// `customFee` + `feePreviewCache.custom` forward.
///
/// Dismissal semantics:
/// - User picks a preset → `Navigator.pop(selectionTitle)`; caller
///   reads it back via [FeeSelectionName.fromString] and dispatches
///   [FeeModalActions.selectFeeOption].
/// - User dismisses without picking → caller dispatches
///   [FeeModalActions.finalizeArmedCustomFee]; below-floor values roll
///   back to the pre-arm selection.
class FeeOptionsModal extends StatefulWidget {
  const FeeOptionsModal({
    super.key,
    required this.viewState,
    required this.actions,
    required this.customFeeColors,
    required this.defaultAbsoluteCustomFee,
  });

  /// Read-only view of the modal's state slice. Concrete adapters in
  /// `presentation/`: `SendCubit`, `TransferBloc`.
  final FeeModalViewState viewState;

  /// Dispatch port. Same adapter as [viewState] in practice; kept
  /// separate so a future read-only embedding could subscribe to
  /// [viewState] without being able to mutate it.
  final FeeModalActions actions;

  /// Theme tokens for the custom-fee tile — differ per surface.
  final FeeModalCustomFeeColors customFeeColors;

  /// Initial position of the absolute/relative toggle when no custom
  /// fee has been committed yet. Send → relative, Swap → absolute,
  /// per historical inconsistency preserved across the refactor.
  final bool defaultAbsoluteCustomFee;

  @override
  State<FeeOptionsModal> createState() => _FeeOptionsModalState();
}

class _FeeOptionsModalState extends State<FeeOptionsModal> {
  // Owned here so [BBKeyboardActions] can attach its "Done" toolbar to the
  // custom-fee field; passed down to [CustomFeeListItem.focusNode].
  final _customFeeNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Fire-and-forget — the controller flips its loading flag, builds
    // three unsigned PSBTs, fills the cache, and emits a new snapshot.
    widget.actions.requestPresetPreviews();
  }

  @override
  void dispose() {
    _customFeeNode.dispose();
    super.dispose();
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
        child: StreamBuilder<FeeModalSnapshot>(
          stream: widget.viewState.snapshots,
          initialData: widget.viewState.snapshot,
          builder: (context, async) {
            final snapshot = async.data ?? widget.viewState.snapshot;
            return BBKeyboardActions(
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
                  _PresetList(snapshot: snapshot),
                  CustomFeeListItem(
                    initialFee: snapshot.customFee,
                    isCommittedAsCustom:
                        snapshot.selectedFeeOption == FeeSelection.custom,
                    feePresets: snapshot.feePresets,
                    txSize: snapshot.txSize,
                    exchangeRate: snapshot.exchangeRate,
                    fiatCurrencyCode: snapshot.fiatCurrencyCode,
                    defaultAbsolute: widget.defaultAbsoluteCustomFee,
                    tileColor: widget.customFeeColors.tile,
                    tileShadowColor: widget.customFeeColors.shadow,
                    unselectedIconColor: widget.customFeeColors.unselectedIcon,
                    previewFeeSat: snapshot.feePreviewCache.custom.feeSat,
                    previewLoading: snapshot.feePreviewCache.customLoading,
                    focusNode: _customFeeNode,
                    onArm: widget.actions.armCustomFee,
                    onDisarm: widget.actions.disarmCustomFee,
                    onPreview: widget.actions.requestCustomFeePreview,
                    // Modal mode: the parent screen runs
                    // [FeeModalActions.finalizeArmedCustomFee] on
                    // dismissal — no per-keystroke commit.
                    onCommit: (_) async {},
                  ),
                  const Gap(24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PresetList extends StatelessWidget {
  const _PresetList({required this.snapshot});
  final FeeModalSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cache = snapshot.feePreviewCache;
    // Titles MUST be FeeSelection.X.title() — the modal returns them
    // via Navigator.pop and the caller routes back through
    // FeeSelectionName.fromString. Localising the title would break
    // that round-trip until the lookup is keyed on the enum instead
    // (pre-existing l10n debt).
    final items = [
      _presetItem(
        context: context,
        title: FeeSelection.fastest.title(),
        description: context.loc.sendEstimatedDelivery10Minutes,
        rate: snapshot.feePresets?.fastest,
        slot: cache.fastest,
        loading: cache.presetsLoading,
        exchangeRate: snapshot.exchangeRate,
        fiatCurrencyCode: snapshot.fiatCurrencyCode,
      ),
      _presetItem(
        context: context,
        title: FeeSelection.economic.title(),
        description: context.loc.sendEstimatedDelivery10to30Minutes,
        rate: snapshot.feePresets?.economic,
        slot: cache.economic,
        loading: cache.presetsLoading,
        exchangeRate: snapshot.exchangeRate,
        fiatCurrencyCode: snapshot.fiatCurrencyCode,
      ),
      _presetItem(
        context: context,
        title: FeeSelection.slow.title(),
        description: context.loc.sendEstimatedDeliveryHours,
        rate: snapshot.feePresets?.slow,
        slot: cache.slow,
        loading: cache.presetsLoading,
        exchangeRate: snapshot.exchangeRate,
        fiatCurrencyCode: snapshot.fiatCurrencyCode,
      ),
    ];
    return SelectableList(
      selectedValue: snapshot.selectedFeeOption.title(),
      items: items,
    );
  }
}

/// Builds one preset row. While `loading` and the cache slot doesn't
/// hold a fee yet, [SelectableListItem.isSubtitle2Loading] is true so
/// the row renders a shimmer instead of an empty subtitle.
SelectableListItem _presetItem({
  required BuildContext context,
  required String title,
  required String description,
  required NetworkFee? rate,
  required BitcoinFeePreviewSlot slot,
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
  final rateLabel = '${rate.value} ${context.loc.sendSatsPerVB}';
  final previewFeeSat = slot.feeSat;
  if (previewFeeSat == null) {
    return SelectableListItem(
      value: title,
      title: title,
      subtitle1: description,
      subtitle2: rateLabel,
      isSubtitle2Loading: loading,
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
        '$rateLabel ~ ${FormatAmount.satsApprox(previewFeeSat)} '
        '${context.loc.sendSats}$fiatPart',
  );
}

/// Theme tokens the custom-fee tile uses. Send and Swap surfaces
/// supply different colors; everything else is identical.
class FeeModalCustomFeeColors {
  const FeeModalCustomFeeColors({
    required this.tile,
    required this.shadow,
    required this.unselectedIcon,
  });

  /// Tile background.
  final Color tile;

  /// Material elevation shadow tint.
  final Color shadow;

  /// Radio-button color when the tile isn't the committed selection.
  final Color unselectedIcon;
}
