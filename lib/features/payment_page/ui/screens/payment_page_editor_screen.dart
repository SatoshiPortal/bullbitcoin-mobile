import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
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
  final _nym = TextEditingController();

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
    _nym.dispose();
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
    if (_nym.text != state.nymDraft) _nym.text = state.nymDraft;
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
      PaymentPageStatus.needsNym => _needsNymView(context, state, cubit),
      PaymentPageStatus.loadFailed => _loadFailedView(context, cubit),
      PaymentPageStatus.archived => _archivedView(context, state, cubit),
      PaymentPageStatus.create ||
      PaymentPageStatus.edit => _editorForm(context, state, cubit),
    };
  }

  // --- DG-6: choose a name (delegates to the shared LA registration) ---
  Widget _needsNymView(
    BuildContext context,
    PaymentPageState state,
    PaymentPageCubit cubit,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.badge_outlined,
          title: context.loc.paymentPageNeedsNymTitle,
          body: context.loc.paymentPageNeedsNymBody,
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
            labelText: context.loc.paymentPageNymLabel,
            helperText: context.loc.paymentPageNymHelper,
          ),
        ),
        const Gap(16),
        Text(
          context.loc.paymentPageRoutingNotice,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(24),
        BBButton.big(
          label: context.loc.paymentPageCreateNymButton,
          onPressed: () => _createNym(cubit),
          disabled: state.submitting || state.nymDraft.trim().isEmpty,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
      ],
    );
  }

  Widget _loadFailedView(BuildContext context, PaymentPageCubit cubit) {
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
      ],
    );
  }

  Widget _archivedView(
    BuildContext context,
    PaymentPageState state,
    PaymentPageCubit cubit,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.pause_circle_outline,
          title: context.loc.paymentPageArchivedTitle,
          body: context.loc.paymentPageArchivedBody,
        ),
        const Gap(24),
        if (state.publicUrl != null) _shareRow(context, state.publicUrl!),
        const Gap(24),
        BBButton.big(
          label: context.loc.paymentPagePublishButton,
          onPressed: () => _save(cubit),
          disabled: state.submitting,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
      ],
    );
  }

  Widget _editorForm(
    BuildContext context,
    PaymentPageState state,
    PaymentPageCubit cubit,
  ) {
    final isCreate = state.status == PaymentPageStatus.create;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        _byteCountedField(
          context: context,
          controller: _description,
          label: context.loc.paymentPageDescriptionLabel,
          hint: context.loc.paymentPageDescriptionHint,
          value: state.description,
          maxBytes: paymentPageDescriptionMaxBytes,
          enabled: !state.submitting,
          onChanged: cubit.descriptionChanged,
          maxLines: 4,
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
        if (!isCreate) ...[
          const Gap(12),
          BBButton.big(
            label: context.loc.paymentPageDeactivateButton,
            onPressed: () => _archive(cubit),
            disabled: state.submitting,
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
        ],
      ],
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

  Future<void> _createNym(PaymentPageCubit cubit) async {
    await cubit.createNym();
  }

  Future<void> _save(PaymentPageCubit cubit) async {
    await cubit.save();
  }

  Future<void> _archive(PaymentPageCubit cubit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.paymentPageArchiveConfirmTitle),
        content: Text(dialogContext.loc.paymentPageArchiveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.loc.paymentPageArchiveConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.loc.paymentPageArchiveConfirmConfirm),
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
