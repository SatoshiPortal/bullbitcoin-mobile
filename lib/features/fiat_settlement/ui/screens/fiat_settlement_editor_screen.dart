import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/exchange_support_chat/ui/exchange_support_chat_router.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/has_bull_bitcoin_account_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/presentation/fiat_settlement_editor_cubit.dart';
import 'package:bb_mobile/features/fiat_settlement/presentation/fiat_settlement_editor_state.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/ui/fiat_settlement_copy.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart'
    show
        AlertDialog,
        BorderRadius,
        BoxDecoration,
        CircularProgressIndicator,
        Container,
        Icons,
        Navigator,
        PopScope,
        Radius,
        Semantics,
        Slider,
        TextButton,
        showDialog;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Shared per-product fiat-settlement editor: the "How do you want to receive
/// the funds?" chooser with inline mix slider, the currency + disclosure gate,
/// and the validated activation outcomes.
class FiatSettlementEditorScreen extends StatelessWidget {
  const FiatSettlementEditorScreen({
    super.key,
    required this.product,
    this.activated = false,
  });

  final FiatSettlementProduct product;

  /// When true the editor was opened right after this product's activation
  /// completed: it shows a success header above the chooser. Purely
  /// presentational — the first-activation rules already derive from the
  /// saved (Bitcoin-only) config in the cubit.
  final bool activated;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FiatSettlementEditorCubit>(
      create: (_) => FiatSettlementEditorCubit(
        facade: locator<FiatSettlementFacade>(),
        hasBullBitcoinAccount: locator<HasBullBitcoinAccountUsecase>(),
        product: product,
      )..load(),
      child: _FiatSettlementEditorView(activated: activated),
    );
  }
}

class _FiatSettlementEditorView extends StatelessWidget {
  const _FiatSettlementEditorView({required this.activated});

  final bool activated;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FiatSettlementEditorCubit, FiatSettlementEditorState>(
      listenWhen: (p, c) => c.status == FiatSettlementEditorStatus.success,
      listener: (context, state) {
        if (context.canPop()) context.pop(true);
      },
      builder: (context, state) {
        final saving = state.status == FiatSettlementEditorStatus.saving;
        return PopScope(
          canPop: !saving,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || !saving) return;
            SnackBarUtils.showSnackBar(
              context,
              context.loc.getPaidFiatSettlementSaving,
            );
          },
          child: BullScaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  BullTopBar(
                    title: context.loc.getPaidFiatSettlementSectionTitle,
                    onBack: () {
                      if (saving) {
                        SnackBarUtils.showSnackBar(
                          context,
                          context.loc.getPaidFiatSettlementSaving,
                        );
                        return;
                      }
                      context.pop();
                    },
                  ),
                  Expanded(child: _body(state)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(FiatSettlementEditorState state) {
    switch (state.status) {
      case FiatSettlementEditorStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case FiatSettlementEditorStatus.loadError:
        return const _LoadError();
      case FiatSettlementEditorStatus.ready:
      case FiatSettlementEditorStatus.saving:
      case FiatSettlementEditorStatus.success:
        return _EditorForm(state: state, activated: activated);
    }
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FiatSettlementEditorCubit>();
    final colors = context.bull;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.loc.getPaidFiatSettlementGenericError,
              textAlign: TextAlign.center,
              style: context.bullText.bodyMedium,
            ),
            const Gap(16),
            BullButton.small(
              label: context.loc.getPaidFiatSettlementRetry,
              onPressed: cubit.load,
              bgColor: colors.primary,
              textColor: colors.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorForm extends StatelessWidget {
  const _EditorForm({required this.state, this.activated = false});
  final FiatSettlementEditorState state;
  final bool activated;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FiatSettlementEditorCubit>();
    final colors = context.bull;
    final saving = state.status == FiatSettlementEditorStatus.saving;
    final wantsFiat = state.mode != FiatSettlementReceiveMode.bitcoin;
    // Fiat/mixed needs a Bull Bitcoin account connected on this device; the
    // login prompt stands in for the currency + disclosure + save section.
    final needsConnection = wantsFiat && !state.hasBullBitcoinAccount;
    // The product settles fully to Bitcoin right now, so Bitcoin is the choice
    // currently in effect. Labelled in both the activated variant and a normal
    // edit of a Bitcoin-only product.
    final bitcoinIsActive = state.saved?.isBitcoinOnly ?? false;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activated) ...[
          _ActivatedHeader(product: state.product),
          const Gap(24),
        ],
        Text(
          context.loc.getPaidFiatSettlementChooserTitle,
          style: context.bullText.titleMedium,
        ),
        const Gap(16),
        _ModeTile(
          label: context.loc.getPaidFiatSettlementChooserBitcoin,
          selected: state.mode == FiatSettlementReceiveMode.bitcoin,
          activeLabel: bitcoinIsActive
              ? context.loc.getPaidFiatSettlementCurrentlyActive
              : null,
          onTap: saving
              ? null
              : () => cubit.selectMode(FiatSettlementReceiveMode.bitcoin),
        ),
        const Gap(8),
        _ModeTile(
          label: context.loc.getPaidFiatSettlementChooserFiat,
          selected: state.mode == FiatSettlementReceiveMode.fiat,
          onTap: saving
              ? null
              : () => cubit.selectMode(FiatSettlementReceiveMode.fiat),
        ),
        const Gap(8),
        _ModeTile(
          label: context.loc.getPaidFiatSettlementChooserMix,
          selected: state.mode == FiatSettlementReceiveMode.mix,
          onTap: saving
              ? null
              : () => cubit.selectMode(FiatSettlementReceiveMode.mix),
        ),
        if (state.mode == FiatSettlementReceiveMode.mix) ...[
          const Gap(16),
          _MixSlider(percentage: state.mixFiatPercentage, disabled: saving),
        ],
        if (needsConnection) ...[
          const Gap(24),
          const _ConnectPanel(),
        ] else ...[
          if (wantsFiat) ...[
            const Gap(24),
            _CurrencyRow(selected: state.currency, disabled: saving),
            if (state.currency != null) ...[
              const Gap(16),
              _DisclosurePanel(currency: state.currency!),
              if (state.requiresAcceptance) ...[
                const Gap(16),
                _UnderstandRow(checked: state.understood, disabled: saving),
              ],
            ],
          ],
          if (state.failure != null) ...[
            const Gap(24),
            _OutcomePanel(state: state),
          ],
          const Gap(32),
          BullButton.big(
            label: saving
                ? context.loc.getPaidFiatSettlementSaving
                : context.loc.getPaidFiatSettlementSave,
            onPressed: state.canSave ? () => _onSave(context, cubit) : () {},
            bgColor: colors.primary,
            textColor: colors.onPrimary,
            disabled: !state.canSave,
          ),
        ],
        if (!(state.saved?.isBitcoinOnly ?? true)) ...[
          const Gap(12),
          BullButton.big(
            label: context.loc.getPaidFiatSettlementTurnOff,
            onPressed: saving ? () {} : () => _onTurnOff(context, cubit),
            bgColor: colors.surface,
            textColor: colors.onSurface,
            outlined: true,
            borderColor: colors.onSurfaceVariant,
            disabled: saving,
          ),
        ],
      ],
    );
  }

  /// Save, first confirming when the action would switch an ACTIVE fiat/mixed
  /// product back to Bitcoin-only (an effective 0%). When the saved config is
  /// already Bitcoin-only, selecting Bitcoin changes nothing, so this just
  /// closes rather than firing a redundant disable — matching the merged
  /// activation chooser's contract that choosing Bitcoin sends nothing (and the
  /// "Continue with Bitcoin only" outcome-panel button's behavior).
  Future<void> _onSave(
    BuildContext context,
    FiatSettlementEditorCubit cubit,
  ) async {
    final switchingToBitcoin = state.effectiveFiatPercentage == 0;
    final wasActive = !(state.saved?.isBitcoinOnly ?? true);
    if (switchingToBitcoin && !wasActive) {
      if (context.canPop()) context.pop(false);
      return;
    }
    if (switchingToBitcoin && wasActive) {
      final confirmed = await _confirmSwitchToBitcoin(context);
      if (!confirmed) return;
    }
    await cubit.save();
  }

  /// The "Turn off fiat conversion" button only shows for an active
  /// fiat/mixed product, so switching it off always requires confirmation.
  Future<void> _onTurnOff(
    BuildContext context,
    FiatSettlementEditorCubit cubit,
  ) async {
    final confirmed = await _confirmSwitchToBitcoin(context);
    if (!confirmed) return;
    await cubit.disable();
  }

  Future<bool> _confirmSwitchToBitcoin(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.getPaidFiatSettlementDisableConfirmTitle),
        content: Text(
          dialogContext.loc.getPaidFiatSettlementDisableConfirmBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              dialogContext.loc.getPaidFiatSettlementDisableConfirmCancel,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              dialogContext.loc.getPaidFiatSettlementDisableConfirmSubmit,
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

/// Shown in place of the currency + disclosure + save section when a fiat or
/// mixed settlement is chosen but no Bull Bitcoin account is connected on this
/// device. Prompts login (WebView, returning to the caller) and reloads.
class _ConnectPanel extends StatelessWidget {
  const _ConnectPanel();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FiatSettlementEditorCubit>();
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.loc.getPaidFiatSettlementConnectPrompt,
            style: context.bullText.bodyMedium,
          ),
          const Gap(16),
          BullButton.big(
            label: context.loc.getPaidFiatSettlementLogin,
            onPressed: () async {
              await context.pushNamed(
                ExchangeRoute.exchangeAuth.name,
                queryParameters: {'returnToCaller': 'true'},
              );
              if (context.mounted) await cubit.load();
            },
            bgColor: colors.primary,
            textColor: colors.onPrimary,
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeLabel,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// A small trailing badge naming this option as the one currently in effect
  /// (e.g. "Currently active" on Bitcoin when the product is Bitcoin-only).
  final String? activeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return BullBorderedTile(
      onTap: onTap,
      backgroundColor: selected ? colors.surfaceContainerHighest : null,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          BullIcon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 22,
            color: selected ? colors.primary : colors.onSurfaceVariant,
          ),
          const Gap(12),
          Expanded(child: Text(label, style: context.bullText.bodyMedium)),
          if (activeLabel != null) ...[
            const Gap(8),
            Text(
              activeLabel!,
              style: context.bullText.labelSmall?.copyWith(
                color: colors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The success headline shown above the chooser when the editor is opened right
/// after an activation. Mirrors the visual language of the product active views'
/// success headers (a large check + the localized per-product title).
class _ActivatedHeader extends StatelessWidget {
  const _ActivatedHeader({required this.product});
  final FiatSettlementProduct product;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        children: [
          BullIcon(Icons.check_circle, size: 72, color: colors.success),
          const Gap(16),
          Text(
            context.fiatSettlementActivatedTitle(product),
            style: context.bullText.titleLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MixSlider extends StatelessWidget {
  const _MixSlider({required this.percentage, required this.disabled});
  final int percentage;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FiatSettlementEditorCubit>();
    final colors = context.bull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.loc.getPaidFiatSettlementSliderBitcoin(100 - percentage),
              style: context.bullText.labelMedium,
            ),
            Text(
              context.loc.getPaidFiatSettlementSliderFiat(percentage),
              style: context.bullText.labelMedium?.copyWith(
                color: colors.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: percentage.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          activeColor: colors.primary,
          onChanged: disabled ? null : (v) => cubit.setMixPercentage(v.round()),
        ),
      ],
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({required this.selected, required this.disabled});
  final FiatCurrency? selected;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FiatSettlementEditorCubit>();
    final colors = context.bull;
    return BullBorderedTile(
      onTap: disabled
          ? null
          : () async {
              final picked = await BullBottomSheet.show<FiatCurrency>(
                context: context,
                child: BullPickerSheet<FiatCurrency>(
                  title: context.loc.getPaidFiatSettlementCurrencyTitle,
                  options: FiatCurrency.values,
                  isSelected: (c) => c == selected,
                  label: (c) => c.code,
                ),
              );
              if (picked != null) cubit.selectCurrency(picked);
            },
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.loc.getPaidFiatSettlementCurrencyLabel,
              style: context.bullText.bodyMedium,
            ),
          ),
          Text(
            selected?.code ?? '—',
            style: context.bullText.bodyMedium?.copyWith(color: colors.primary),
          ),
          const Gap(8),
          BullIcon(
            Icons.chevron_right,
            size: 20,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _DisclosurePanel extends StatelessWidget {
  const _DisclosurePanel({required this.currency});
  final FiatCurrency currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.fiatSettlementDisclosure(currency),
            style: context.bullText.bodySmall,
          ),
          const Gap(12),
          Text(
            context.loc.getPaidFiatSettlementFallbackDisclosure,
            style: context.bullText.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _UnderstandRow extends StatelessWidget {
  const _UnderstandRow({required this.checked, required this.disabled});
  final bool checked;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FiatSettlementEditorCubit>();
    return Row(
      children: [
        BullCheckbox(
          checked: checked,
          onChanged: disabled ? null : cubit.setUnderstood,
        ),
        const Gap(12),
        Expanded(
          child: Text(
            context.loc.getPaidFiatSettlementUnderstandCheckbox,
            style: context.bullText.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// Renders the validated outcome action-sets. "Continue with Bitcoin only" is
/// offered only on a first activation; edits show corrective actions only.
class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({required this.state});
  final FiatSettlementEditorState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FiatSettlementEditorCubit>();
    final colors = context.bull;
    final failure = state.failure!;
    final showContinueBitcoin = state.isFirstActivation;

    final (String message, List<Widget> actions) = switch (failure.kind) {
      FiatSettlementFailureKind.kycRequired => (
        context.loc.getPaidFiatSettlementKycRequired,
        [
          _action(
            context,
            context.loc.getPaidFiatSettlementCompleteKyc,
            () => context.pushNamed(ExchangeRoute.exchangeKyc.name),
          ),
          _support(context),
          if (showContinueBitcoin) _continueBitcoin(context, cubit),
        ],
      ),
      FiatSettlementFailureKind.credentialProblem => (
        context.loc.getPaidFiatSettlementCredentialProblem,
        [
          _action(
            context,
            context.loc.getPaidFiatSettlementReconnect,
            () => _reconnect(context, cubit),
          ),
          _support(context),
          if (showContinueBitcoin) _continueBitcoin(context, cubit),
        ],
      ),
      FiatSettlementFailureKind.dependencyUnavailable => (
        context.loc.getPaidFiatSettlementDependencyUnavailable,
        [
          _action(context, context.loc.getPaidFiatSettlementRetry, cubit.save),
          _support(context),
          if (showContinueBitcoin) _continueBitcoin(context, cubit),
        ],
      ),
      FiatSettlementFailureKind.bullnymUnreachable => (
        context.loc.getPaidFiatSettlementUnreachable,
        [
          _action(context, context.loc.getPaidFiatSettlementRetry, cubit.save),
          _support(context),
        ],
      ),
      FiatSettlementFailureKind.invalidInput ||
      FiatSettlementFailureKind.unexpected => (
        context.loc.getPaidFiatSettlementGenericError,
        [_action(context, context.loc.getPaidFiatSettlementRetry, cubit.save)],
      ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: context.bullText.bodyMedium),
          const Gap(12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, String label, VoidCallback onTap) {
    final colors = context.bull;
    return BullButton.small(
      label: label,
      onPressed: onTap,
      bgColor: colors.primary,
      textColor: colors.onPrimary,
    );
  }

  Widget _support(BuildContext context) {
    final colors = context.bull;
    return BullButton.small(
      label: context.loc.getPaidFiatSettlementContactSupport,
      onPressed: () =>
          context.pushNamed(ExchangeSupportChatRoute.supportChat.name),
      bgColor: colors.surface,
      textColor: colors.onSurface,
      outlined: true,
      borderColor: colors.onSurfaceVariant,
    );
  }

  Widget _continueBitcoin(
    BuildContext context,
    FiatSettlementEditorCubit cubit,
  ) {
    final colors = context.bull;
    return BullButton.small(
      label: context.loc.getPaidFiatSettlementContinueBitcoinOnly,
      onPressed: () {
        // When the saved config is already Bitcoin-only there is nothing to
        // change server-side — just close the editor instead of a redundant
        // disable call.
        if (state.saved?.isBitcoinOnly ?? true) {
          if (context.canPop()) context.pop(false);
        } else {
          cubit.disable();
        }
      },
      bgColor: colors.surface,
      textColor: colors.onSurface,
      outlined: true,
      borderColor: colors.onSurfaceVariant,
    );
  }

  Future<void> _reconnect(
    BuildContext context,
    FiatSettlementEditorCubit cubit,
  ) async {
    await context.pushNamed(
      ExchangeRoute.exchangeAuth.name,
      queryParameters: {'returnToCaller': 'true'},
    );
    if (context.mounted) await cubit.load();
  }
}
