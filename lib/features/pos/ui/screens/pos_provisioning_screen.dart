import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/pos/domain/pos_validation.dart';
import 'package:bb_mobile/features/pos/presentation/pos_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/pos_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Point of Sale provisioning screen (ISS-C-05 legacy `core/widgets`). It
/// collects a label + display currency, states the ROUTE-3W routing notice, and
/// - for an existing POS - surfaces the shareable terminal URL (copy + external
/// open only, DG-P4). It renders NO in-app terminal and NO invoice UI (DELTA 2).
class PosProvisioningScreen extends StatefulWidget {
  const PosProvisioningScreen({super.key});

  @override
  State<PosProvisioningScreen> createState() => _PosProvisioningScreenState();
}

class _PosProvisioningScreenState extends State<PosProvisioningScreen> {
  final _label = TextEditingController();
  final _alias = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<PosCubit>().load();
  }

  @override
  void dispose() {
    _label.dispose();
    _alias.dispose();
    super.dispose();
  }

  void _syncControllers(PosState state) {
    if (_label.text != state.label) _label.text = state.label;
    if (_alias.text != state.aliasDraft) _alias.text = state.aliasDraft;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PosCubit, PosState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure && current.failure != null,
      listener: (context, state) {
        final failure = state.failure;
        if (failure == null) return;
        SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
      },
      builder: (context, state) {
        _syncControllers(state);
        return PopScope(
          canPop: !state.submitting,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || !state.submitting) return;
            SnackBarUtils.showSnackBar(
              context,
              context.loc.posOperationInProgress,
            );
          },
          child: Scaffold(
            appBar: AppBar(title: Text(context.loc.posScreenTitle)),
            body: SafeArea(child: _body(context, state)),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, PosState state) {
    final cubit = context.read<PosCubit>();
    return switch (state.status) {
      PosStatus.loading => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoadingBoxContent(height: 72),
            LoadingLineContent(),
            LoadingLineContent(width: 220),
          ],
        ),
      ),
      PosStatus.unsupported => _unsupportedView(context, state),
      PosStatus.needsNym => _needsNymView(context, state),
      PosStatus.loadFailed => _loadFailedView(context, state, cubit),
      PosStatus.archived => _archivedView(context, state, cubit),
      PosStatus.create || PosStatus.edit => _form(context, state, cubit),
    };
  }

  Widget _unsupportedView(BuildContext context, PosState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.visibility_off_outlined,
          title: context.loc.posPermanentNamesUnavailableTitle,
          body: context.loc.posPermanentNamesUnavailableBody,
        ),
        if (state.walletBehavior != null)
          _WalletBehaviorControls(
            behavior: state.walletBehavior!,
            saving: state.walletBehaviorSaving,
          ),
      ],
    );
  }

  Widget _needsNymView(BuildContext context, PosState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.badge_outlined,
          title: context.loc.posNeedsPermanentNymTitle,
          body: context.loc.posNeedsPermanentNymBody,
        ),
        if (state.walletBehavior != null)
          _WalletBehaviorControls(
            behavior: state.walletBehavior!,
            saving: state.walletBehaviorSaving,
          ),
      ],
    );
  }

  Widget _loadFailedView(BuildContext context, PosState state, PosCubit cubit) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.error_outline,
          title: context.loc.posLoadFailedTitle,
          body: context.loc.posLoadFailedBody,
        ),
        const Gap(24),
        BBButton.big(
          label: context.loc.posRetryButton,
          iconData: Icons.refresh,
          iconFirst: true,
          onPressed: cubit.load,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        // The behavior controls only need the local wallet, so they stay
        // reachable even while the server-backed POS load is failing.
        if (state.walletBehavior != null)
          _WalletBehaviorControls(
            behavior: state.walletBehavior!,
            saving: state.walletBehaviorSaving,
          ),
      ],
    );
  }

  Widget _archivedView(BuildContext context, PosState state, PosCubit cubit) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.pause_circle_outline,
          title: context.loc.posArchivedTitle,
          body: context.loc.posArchivedBody,
        ),
        const Gap(24),
        _permanentAliasSection(context, state, cubit),
        const Gap(16),
        _SurfaceOnlineControl(
          online: false,
          saving: state.submitting,
          onChanged: (online) =>
              _setOnline(cubit: cubit, state: state, online: online),
        ),
        const Gap(24),
        if (state.terminalUrl != null) _shareRow(context, state.terminalUrl!),
        if (state.walletBehavior != null)
          _WalletBehaviorControls(
            behavior: state.walletBehavior!,
            saving: state.walletBehaviorSaving,
          ),
      ],
    );
  }

  Widget _form(BuildContext context, PosState state, PosCubit cubit) {
    final isCreate = state.status == PosStatus.create;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.loc.posRoutingNotice,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(20),
        if (state.submissionUncertain) ...[
          _Banner(
            icon: Icons.help_outline,
            text: context.loc.posSubmissionUncertain,
          ),
          const Gap(16),
        ],
        _permanentAliasSection(context, state, cubit),
        if (!isCreate) ...[
          const Gap(16),
          _SurfaceOnlineControl(
            online: true,
            saving: state.submitting,
            onChanged: (online) =>
                _setOnline(cubit: cubit, state: state, online: online),
          ),
        ],
        const Gap(20),
        TextField(
          controller: _label,
          enabled: !state.submitting,
          onChanged: cubit.labelChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: context.loc.posLabelFieldLabel,
            hintText: context.loc.posLabelFieldHint,
            errorText: state.invalidField == PosField.label
                ? context.loc.posLabelError
                : null,
            counterText: context.loc.posByteCounter(
              posByteLength(state.label),
              posLabelMaxBytes,
            ),
          ),
        ),
        const Gap(16),
        _currencyField(context, state, cubit),
        if (!isCreate && state.terminalUrl != null) ...[
          const Gap(24),
          _shareRow(context, state.terminalUrl!),
        ],
        const Gap(24),
        BBButton.big(
          label: state.submitting
              ? context.loc.posSubmitting
              : isCreate
              ? context.loc.posCreateButton
              : context.loc.posSaveButton,
          onPressed: () => _provision(cubit),
          // Always tappable: provision() validates on tap and surfaces the
          // specific invalid field, rather than silently disabling.
          disabled: state.submitting,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
        if (state.walletBehavior != null)
          _WalletBehaviorControls(
            behavior: state.walletBehavior!,
            saving: state.walletBehaviorSaving,
          ),
      ],
    );
  }

  Widget _permanentAliasSection(
    BuildContext context,
    PosState state,
    PosCubit cubit,
  ) {
    final alias = state.permanentAlias;
    if (alias != null) return _PermanentAliasSummary(alias: alias);
    return TextField(
      key: const Key('pos_alias_field'),
      controller: _alias,
      enabled: !state.submitting,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: 32,
      onChanged: cubit.aliasDraftChanged,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: context.loc.posAliasLabel,
        helperText: context.loc.posAliasHelper,
        errorText: state.invalidField == PosField.alias
            ? context.loc.posAliasInvalid
            : null,
        errorMaxLines: 2,
      ),
    );
  }

  Widget _currencyField(BuildContext context, PosState state, PosCubit cubit) {
    if (state.currenciesUnavailable) {
      return Row(
        children: [
          Expanded(
            child: _InfoRow(
              label: context.loc.posCurrencyLabel,
              value: context.loc.posCurrenciesUnavailable(
                state.displayCurrency.isEmpty
                    ? posFallbackCurrency
                    : state.displayCurrency,
              ),
            ),
          ),
          TextButton(
            onPressed: cubit.retryCurrencies,
            child: Text(context.loc.posRetryCurrencies),
          ),
        ],
      );
    }

    final codes = <String>{
      ...state.currencies.map((c) => c.code),
      if (state.displayCurrency.isNotEmpty) state.displayCurrency,
    }.toList();
    return DropdownButtonFormField<String>(
      initialValue: state.displayCurrency.isEmpty
          ? null
          : state.displayCurrency,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: context.loc.posCurrencyLabel,
        errorText: state.invalidField == PosField.displayCurrency
            ? context.loc.posCurrencyError
            : null,
      ),
      items: [
        for (final code in codes)
          DropdownMenuItem(value: code, child: Text(code)),
      ],
      onChanged: state.submitting
          ? null
          : (value) {
              if (value != null) cubit.displayCurrencyChanged(value);
            },
    );
  }

  Widget _shareRow(BuildContext context, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.posShareLabel,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(8),
        CopyInput(text: url, maxLines: 1, overflow: TextOverflow.ellipsis),
        const Gap(8),
        BBButton.big(
          label: context.loc.posOpenLink,
          iconData: Icons.open_in_new,
          iconFirst: true,
          onPressed: () => _openLink(url),
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }

  Future<void> _provision(PosCubit cubit) async {
    final state = cubit.state;
    if (state.permanentAlias == null && state.aliasDraft.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.loc.posAliasConfirmTitle),
          content: Text(
            dialogContext.loc.posAliasConfirmBody(state.aliasDraft),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.loc.posAliasConfirmCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.loc.posAliasConfirmSubmit),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    await cubit.provision();
  }

  Future<void> _setOnline({
    required PosCubit cubit,
    required PosState state,
    required bool online,
  }) async {
    if (online) {
      await _provision(cubit);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.posTurnOffConfirmTitle),
        content: Text(dialogContext.loc.posTurnOffConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.loc.posTurnOffConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.loc.posTurnOffConfirmSubmit),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (!state.isOnline) return;
    await cubit.setOnline(false);
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Guarded external launch only - the terminal URL is never webviewed
    // (DELTA 2 / §8.9).
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _PermanentAliasSummary extends StatelessWidget {
  final String alias;

  const _PermanentAliasSummary({required this.alias});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: context.loc.posAliasLabel, value: alias),
          const Gap(8),
          Text(
            context.loc.posAliasReadOnly,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceOnlineControl extends StatelessWidget {
  final bool online;
  final bool saving;
  final ValueChanged<bool> onChanged;

  const _SurfaceOnlineControl({
    required this.online,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        key: const Key('pos_online_switch'),
        value: online,
        onChanged: saving ? null : onChanged,
        title: Text(context.loc.posOnlineToggleLabel),
        subtitle: Text(context.loc.posOnlineToggleBody),
      ),
    );
  }
}

/// Reserved-wallet behavior controls (auto-sweep + hide-on-home) for wallet 103.
/// Mirrors BTCPay's `_BtcpayWalletBehaviorTile`; the safe defaults are applied
/// at wallet creation, these rows only let the user review and change them.
class _WalletBehaviorControls extends StatelessWidget {
  final GetPaidWalletBehavior behavior;
  final bool saving;

  const _WalletBehaviorControls({required this.behavior, required this.saving});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PosCubit>();
    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          ListTile(title: Text(context.loc.getPaidWalletSettingsSectionTitle)),
          SwitchListTile(
            value: behavior.autoSweepEnabled,
            onChanged: saving
                ? null
                : (value) => cubit.updateWalletBehavior(
                    walletId: behavior.walletId,
                    autoSweepEnabled: value,
                  ),
            title: Text(context.loc.getPaidWalletAutoSweepLabel),
            subtitle: Text(context.loc.getPaidWalletAutoSweepInfo),
          ),
          SwitchListTile(
            value: behavior.hideOnHome,
            onChanged: saving
                ? null
                : (value) => cubit.updateWalletBehavior(
                    walletId: behavior.walletId,
                    hideOnHome: value,
                  ),
            title: Text(context.loc.getPaidWalletHideOnHomeLabel),
            subtitle: Text(context.loc.getPaidWalletHideOnHomeInfo),
          ),
        ],
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _StatusNotice({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.appColors.primary, size: 48),
        const Gap(16),
        Text(title, style: context.font.titleLarge),
        const Gap(8),
        Text(
          body,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Banner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.appColors.textMuted, size: 20),
        const Gap(8),
        Expanded(
          child: Text(
            text,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(4),
        Text(value, style: context.font.bodyLarge),
      ],
    );
  }
}
