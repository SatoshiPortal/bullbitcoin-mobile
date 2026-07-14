import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_validation.dart';
import 'package:bb_mobile/features/payment_page/presentation/payment_page_cubit.dart';
import 'package:bb_mobile/features/payment_page/presentation/payment_page_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentPageEditorScreen extends StatefulWidget {
  const PaymentPageEditorScreen({super.key});

  @override
  State<PaymentPageEditorScreen> createState() =>
      _PaymentPageEditorScreenState();
}

class _PaymentPageEditorScreenState extends State<PaymentPageEditorScreen> {
  final _header = TextEditingController();
  final _description = TextEditingController();
  final _website = TextEditingController();
  final _twitter = TextEditingController();
  final _instagram = TextEditingController();
  final _alias = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<PaymentPageCubit>().load();
  }

  @override
  void dispose() {
    _header.dispose();
    _description.dispose();
    _website.dispose();
    _twitter.dispose();
    _instagram.dispose();
    _alias.dispose();
    super.dispose();
  }

  void _syncControllers(PaymentPageState state) {
    if (_header.text != state.header) _header.text = state.header;
    if (_description.text != state.description) {
      _description.text = state.description;
    }
    if (_website.text != state.website) _website.text = state.website;
    if (_twitter.text != state.twitter) _twitter.text = state.twitter;
    if (_instagram.text != state.instagram) _instagram.text = state.instagram;
    if (_alias.text != state.aliasDraft) _alias.text = state.aliasDraft;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentPageCubit, PaymentPageState>(
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
              context.loc.paymentPageOperationInProgress,
            );
          },
          child: Scaffold(
            appBar: AppBar(title: Text(context.loc.paymentPageScreenTitle)),
            body: SafeArea(child: _body(context, state)),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, PaymentPageState state) {
    final cubit = context.read<PaymentPageCubit>();
    return switch (state.status) {
      PaymentPageStatus.loading => const Padding(
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
      PaymentPageStatus.unsupported => _unsupportedView(context, state),
      PaymentPageStatus.needsNym => _needsNymView(context, state),
      PaymentPageStatus.loadFailed => _loadFailedView(context, state, cubit),
      PaymentPageStatus.archived => _archivedView(context, state, cubit),
      PaymentPageStatus.create ||
      PaymentPageStatus.edit => _editorForm(context, state, cubit),
    };
  }

  Widget _unsupportedView(BuildContext context, PaymentPageState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.visibility_off_outlined,
          title: context.loc.paymentPagePermanentNamesUnavailableTitle,
          body: context.loc.paymentPagePermanentNamesUnavailableBody,
        ),
        if (state.walletBehavior != null)
          _WalletBehaviorControls(
            behavior: state.walletBehavior!,
            saving: state.walletBehaviorSaving,
          ),
      ],
    );
  }

  Widget _needsNymView(BuildContext context, PaymentPageState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.badge_outlined,
          title: context.loc.paymentPageNeedsPermanentNymTitle,
          body: context.loc.paymentPageNeedsPermanentNymBody,
        ),
        if (state.walletBehavior != null)
          _WalletBehaviorControls(
            behavior: state.walletBehavior!,
            saving: state.walletBehaviorSaving,
          ),
      ],
    );
  }

  Widget _loadFailedView(
    BuildContext context,
    PaymentPageState state,
    PaymentPageCubit cubit,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.error_outline,
          title: context.loc.paymentPageLoadFailedTitle,
          body: context.loc.paymentPageLoadFailedBody,
        ),
        const Gap(24),
        BBButton.big(
          label: context.loc.paymentPageRetryButton,
          iconData: Icons.refresh,
          iconFirst: true,
          onPressed: cubit.load,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        // The behavior controls only need the local wallet, so they stay
        // reachable even while the server-backed page load is failing.
        if (state.walletBehavior != null)
          _WalletBehaviorControls(
            behavior: state.walletBehavior!,
            saving: state.walletBehaviorSaving,
          ),
      ],
    );
  }

  Widget _archivedView(
    BuildContext context,
    PaymentPageState state,
    PaymentPageCubit cubit,
  ) {
    return _editorForm(context, state, cubit, isArchived: true);
  }

  Widget _editorForm(
    BuildContext context,
    PaymentPageState state,
    PaymentPageCubit cubit, {
    bool isArchived = false,
  }) {
    final isCreate = state.status == PaymentPageStatus.create;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isArchived)
          _StatusNotice(
            icon: Icons.pause_circle_outline,
            title: context.loc.paymentPageArchivedTitle,
            body: context.loc.paymentPageArchivedBody,
          )
        else
          Text(
            context.loc.paymentPageRoutingNotice,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        const Gap(20),
        if (state.submissionUncertain) ...[
          _Banner(
            icon: Icons.help_outline,
            text: context.loc.paymentPageSubmissionUncertain,
          ),
          const Gap(16),
        ],
        _permanentAliasSection(context, state, cubit),
        if (!isCreate) ...[
          const Gap(16),
          _SurfaceOnlineControl(
            online: !isArchived,
            saving: state.submitting,
            onChanged: (online) =>
                _setOnline(cubit: cubit, state: state, online: online),
          ),
        ],
        const Gap(20),
        _byteCountedField(
          context: context,
          controller: _header,
          label: context.loc.paymentPageHeaderLabel,
          hint: context.loc.paymentPageHeaderHint,
          value: state.header,
          maxBytes: paymentPageHeaderMaxBytes,
          enabled: !state.submitting,
          onChanged: cubit.headerChanged,
          errorText: state.invalidField == PaymentPageField.header
              ? context.loc.paymentPageHeaderError
              : null,
        ),
        const Gap(16),
        _characterCountedDescriptionField(
          context: context,
          controller: _description,
          label: context.loc.paymentPageDescriptionLabel,
          hint: context.loc.paymentPageDescriptionHint,
          value: state.description,
          enabled: !state.submitting,
          onChanged: cubit.descriptionChanged,
          errorText: state.invalidField == PaymentPageField.description
              ? context.loc.paymentPageDescriptionError
              : null,
        ),
        const Gap(16),
        _currencyField(context, state, cubit),
        const Gap(16),
        TextField(
          controller: _website,
          enabled: !state.submitting,
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: cubit.websiteChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: context.loc.paymentPageWebsiteLabel,
            errorText: state.invalidField == PaymentPageField.website
                ? context.loc.paymentPageWebsiteError
                : null,
          ),
        ),
        const Gap(16),
        TextField(
          controller: _twitter,
          enabled: !state.submitting,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: cubit.twitterChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: context.loc.paymentPageTwitterLabel,
            errorText: state.invalidField == PaymentPageField.twitter
                ? context.loc.paymentPageTwitterError
                : null,
          ),
        ),
        const Gap(16),
        TextField(
          controller: _instagram,
          enabled: !state.submitting,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: cubit.instagramChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: context.loc.paymentPageInstagramLabel,
            errorText: state.invalidField == PaymentPageField.instagram
                ? context.loc.paymentPageInstagramError
                : null,
          ),
        ),
        if (!isCreate && state.publicUrl != null) ...[
          const Gap(24),
          _shareRow(context, state.publicUrl!),
        ],
        const Gap(24),
        BBButton.big(
          label: state.submitting
              ? context.loc.paymentPageSubmitting
              : isArchived
              ? context.loc.paymentPageSaveAndTurnOnButton
              : isCreate
              ? context.loc.paymentPageCreateButton
              : context.loc.paymentPageSaveButton,
          onPressed: () => _save(cubit),
          // Always tappable: save() validates on tap and surfaces the specific
          // invalid field, rather than silently disabling with no feedback.
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
    PaymentPageState state,
    PaymentPageCubit cubit,
  ) {
    final alias = state.permanentAlias;
    if (alias != null) {
      return _PermanentAliasSummary(alias: alias);
    }
    return TextField(
      key: const Key('payment_page_alias_field'),
      controller: _alias,
      enabled: !state.submitting,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: 32,
      onChanged: cubit.aliasDraftChanged,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: context.loc.paymentPageAliasLabel,
        helperText: context.loc.paymentPageAliasHelper,
        errorText: state.invalidField == PaymentPageField.alias
            ? context.loc.paymentPageAliasInvalid
            : null,
        errorMaxLines: 2,
      ),
    );
  }

  Widget _currencyField(
    BuildContext context,
    PaymentPageState state,
    PaymentPageCubit cubit,
  ) {
    if (state.currenciesUnavailable) {
      return Row(
        children: [
          Expanded(
            child: _InfoRow(
              label: context.loc.paymentPageCurrencyLabel,
              value: context.loc.paymentPageCurrenciesUnavailable(
                state.displayCurrency.isEmpty
                    ? paymentPageFallbackCurrency
                    : state.displayCurrency,
              ),
            ),
          ),
          TextButton(
            onPressed: cubit.retryCurrencies,
            child: Text(context.loc.paymentPageRetryCurrencies),
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
        labelText: context.loc.paymentPageCurrencyLabel,
        errorText: state.invalidField == PaymentPageField.displayCurrency
            ? context.loc.paymentPageCurrencyError
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

  Widget _byteCountedField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required String value,
    required int maxBytes,
    required bool enabled,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        hintText: hint,
        errorText: errorText,
        counterText: context.loc.paymentPageByteCounter(
          paymentPageByteLength(value),
          maxBytes,
        ),
      ),
    );
  }

  Widget _characterCountedDescriptionField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required String value,
    required bool enabled,
    required ValueChanged<String> onChanged,
    String? errorText,
  }) {
    final byteCount = paymentPageByteLength(value);
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: 3,
      onChanged: onChanged,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        helperText: hint,
        errorText: byteCount > paymentPageDescriptionMaxBytes
            ? context.loc.paymentPageDescriptionByteLimit(
                byteCount,
                paymentPageDescriptionMaxBytes,
              )
            : errorText,
        errorMaxLines: 2,
        counterText: context.loc.paymentPageByteCounter(
          paymentPageCharacterLength(value),
          paymentPageDescriptionMaxCharacters,
        ),
      ),
    );
  }

  Widget _shareRow(BuildContext context, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.paymentPageShareLabel,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(8),
        CopyInput(text: url, maxLines: 1, overflow: TextOverflow.ellipsis),
        const Gap(8),
        BBButton.big(
          label: context.loc.paymentPageOpenLink,
          iconData: Icons.open_in_new,
          iconFirst: true,
          onPressed: () => _openLink(url),
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }

  Future<void> _save(PaymentPageCubit cubit) async {
    final state = cubit.state;
    if (state.permanentAlias == null && state.aliasDraft.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.loc.paymentPageAliasConfirmTitle),
          content: Text(
            dialogContext.loc.paymentPageAliasConfirmBody(state.aliasDraft),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.loc.paymentPageAliasConfirmCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.loc.paymentPageAliasConfirmSubmit),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    await cubit.save();
  }

  Future<void> _setOnline({
    required PaymentPageCubit cubit,
    required PaymentPageState state,
    required bool online,
  }) async {
    if (online) {
      await _save(cubit);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.paymentPageTurnOffConfirmTitle),
        content: Text(dialogContext.loc.paymentPageTurnOffConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.loc.paymentPageTurnOffConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.loc.paymentPageTurnOffConfirmSubmit),
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
          _InfoRow(label: context.loc.paymentPageAliasLabel, value: alias),
          const Gap(8),
          Text(
            context.loc.paymentPageAliasReadOnly,
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
        key: const Key('payment_page_online_switch'),
        value: online,
        onChanged: saving ? null : onChanged,
        title: Text(context.loc.paymentPageOnlineToggleLabel),
        subtitle: Text(context.loc.paymentPageOnlineToggleBody),
      ),
    );
  }
}

/// Reserved-wallet behavior controls (auto-sweep + hide-on-home) for wallet 102.
/// Mirrors BTCPay's `_BtcpayWalletBehaviorTile`; the safe defaults are applied
/// at wallet creation, these rows only let the user review and change them.
class _WalletBehaviorControls extends StatelessWidget {
  final GetPaidWalletBehavior behavior;
  final bool saving;

  const _WalletBehaviorControls({required this.behavior, required this.saving});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PaymentPageCubit>();
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
