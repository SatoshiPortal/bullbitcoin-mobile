import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/get_paid_settings/public/automated_backup_consent.dart';
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
  final _nym = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<PosCubit>().load();
  }

  @override
  void dispose() {
    _label.dispose();
    _nym.dispose();
    super.dispose();
  }

  void _syncControllers(PosState state) {
    if (_label.text != state.label) _label.text = state.label;
    if (_nym.text != state.nymDraft) _nym.text = state.nymDraft;
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
      PosStatus.loading => const Center(child: CircularProgressIndicator()),
      PosStatus.needsNym => _needsNymView(context, state, cubit),
      PosStatus.loadFailed => _loadFailedView(context, cubit),
      PosStatus.archived => _archivedView(context, state, cubit),
      PosStatus.create || PosStatus.edit => _form(context, state, cubit),
    };
  }

  // --- DG-P6: choose a name (delegates to the shared LA registration) ---
  Widget _needsNymView(BuildContext context, PosState state, PosCubit cubit) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.badge_outlined,
          title: context.loc.posNeedsNymTitle,
          body: context.loc.posNeedsNymBody,
        ),
        const Gap(24),
        TextField(
          controller: _nym,
          enabled: !state.submitting,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: cubit.nymDraftChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: context.loc.posNymLabel,
            helperText: context.loc.posNymHelper,
          ),
        ),
        const Gap(16),
        Text(
          context.loc.posRoutingNotice,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(24),
        BBButton.big(
          label: context.loc.posCreateNymButton,
          onPressed: () => _createNym(cubit),
          disabled: state.submitting || state.nymDraft.trim().isEmpty,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
      ],
    );
  }

  Widget _loadFailedView(BuildContext context, PosCubit cubit) {
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
        if (state.terminalUrl != null) _shareRow(context, state.terminalUrl!),
        const Gap(24),
        BBButton.big(
          label: context.loc.posPublishButton,
          onPressed: () => _provision(cubit),
          disabled: state.submitting,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
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
        TextField(
          controller: _label,
          enabled: !state.submitting,
          onChanged: cubit.labelChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: context.loc.posLabelFieldLabel,
            hintText: context.loc.posLabelFieldHint,
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
          disabled: !state.canSubmit,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
        if (!isCreate) ...[
          const Gap(12),
          BBButton.big(
            label: context.loc.posDeactivateButton,
            onPressed: () => _archive(cubit),
            disabled: state.submitting,
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
        ],
      ],
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
      initialValue: state.displayCurrency.isEmpty ? null : state.displayCurrency,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: context.loc.posCurrencyLabel,
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

  Future<void> _createNym(PosCubit cubit) async {
    if (!await ensureAutomatedBackupConsent(context)) return;
    if (!mounted) return;
    await cubit.createNym();
  }

  Future<void> _provision(PosCubit cubit) async {
    // Creating the POS provisions wallet 103 and rides the next backup
    // snapshot, so ensure the automated-backup disclosure is acknowledged
    // (no-op if already consented).
    if (!await ensureAutomatedBackupConsent(context)) return;
    if (!mounted) return;
    await cubit.provision();
  }

  Future<void> _archive(PosCubit cubit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.posArchiveConfirmTitle),
        content: Text(dialogContext.loc.posArchiveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.loc.posArchiveConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.loc.posArchiveConfirmConfirm),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await cubit.archive();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Guarded external launch only - the terminal URL is never webviewed
    // (DELTA 2 / §8.9).
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
