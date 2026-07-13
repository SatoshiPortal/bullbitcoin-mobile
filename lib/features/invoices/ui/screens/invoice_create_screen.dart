import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_create_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_create_state.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_failure_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// The create-invoice screen (single route, one widget). Amount (one-of) +
/// details + rails + a 1–7 day expiry; on success it surfaces the share URL
/// (copy + guarded external open only, no QR in v1). Legacy `core/widgets`.
class InvoiceCreateScreen extends StatefulWidget {
  const InvoiceCreateScreen({super.key});

  @override
  State<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends State<InvoiceCreateScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _recipient = TextEditingController();
  final _number = TextEditingController();
  final _memo = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _recipient.dispose();
    _number.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _sync(InvoiceCreateState state) {
    if (_amount.text != state.amountInput) _amount.text = state.amountInput;
    if (_description.text != state.publicDescription) {
      _description.text = state.publicDescription;
    }
    if (_recipient.text != state.recipientName) {
      _recipient.text = state.recipientName;
    }
    if (_number.text != state.invoiceNumber) _number.text = state.invoiceNumber;
    if (_memo.text != state.privateMemo) _memo.text = state.privateMemo;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InvoiceCreateCubit, InvoiceCreateState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure && current.failure != null,
      listener: (context, state) {
        final failure = state.failure;
        if (failure != null) {
          SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
        }
      },
      builder: (context, state) {
        _sync(state);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              state.isSubmitted
                  ? context.loc.invoiceCreatedTitle
                  : context.loc.invoiceCreateTitle,
            ),
          ),
          body: SafeArea(
            child: state.isSubmitted
                ? _success(context, state)
                : _form(context, state),
          ),
        );
      },
    );
  }

  Widget _success(BuildContext context, InvoiceCreateState state) {
    final url = state.result!.shareUrl.value;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 56,
          color: context.appColors.success,
        ),
        const Gap(16),
        Text(context.loc.invoiceShareLabel, style: context.font.titleLarge),
        const Gap(12),
        CopyInput(text: url, maxLines: 2, overflow: TextOverflow.ellipsis),
        const Gap(12),
        BBButton.big(
          label: context.loc.invoiceOpenLink,
          iconData: Icons.open_in_new,
          iconFirst: true,
          onPressed: () => _openLink(url),
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        const Gap(12),
        BBButton.big(
          label: context.loc.invoiceDoneButton,
          onPressed: () => context.pop(),
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
      ],
    );
  }

  Widget _form(BuildContext context, InvoiceCreateState state) {
    final cubit = context.read<InvoiceCreateCubit>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<InvoiceAmountMode>(
          segments: [
            ButtonSegment(
              value: InvoiceAmountMode.sats,
              label: Text(context.loc.invoiceAmountModeSats),
            ),
            ButtonSegment(
              value: InvoiceAmountMode.fiat,
              label: Text(context.loc.invoiceAmountModeFiat),
            ),
          ],
          selected: {state.amountMode},
          onSelectionChanged: state.submitting
              ? null
              : (selection) => cubit.amountModeChanged(selection.first),
        ),
        const Gap(12),
        TextField(
          controller: _amount,
          enabled: !state.submitting,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: cubit.amountChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: state.amountMode == InvoiceAmountMode.sats
                ? context.loc.invoiceAmountSatsLabel
                : context.loc.invoiceAmountFiatLabel,
            errorText: state.invalidField == InvoiceCreateField.amount
                ? context.loc.invoiceAmountError
                : null,
          ),
        ),
        if (state.amountMode == InvoiceAmountMode.fiat) ...[
          const Gap(12),
          _currencyField(context, state, cubit),
        ],
        const Gap(20),
        Text(context.loc.invoiceRailsLabel, style: context.font.bodyLarge),
        SwitchListTile(
          value: state.acceptLn,
          onChanged: state.submitting ? null : cubit.acceptLnChanged,
          title: Text(context.loc.invoiceAcceptLn),
        ),
        SwitchListTile(
          value: state.acceptLiquid,
          onChanged: state.submitting ? null : cubit.acceptLiquidChanged,
          title: Text(context.loc.invoiceAcceptLiquid),
        ),
        SwitchListTile(
          value: state.acceptBtc,
          onChanged: state.submitting ? null : cubit.acceptBtcChanged,
          title: Text(context.loc.invoiceAcceptBtc),
        ),
        const Gap(12),
        TextField(
          controller: _description,
          enabled: !state.submitting,
          onChanged: cubit.publicDescriptionChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: context.loc.invoicePublicDescriptionLabel,
          ),
        ),
        const Gap(12),
        TextField(
          controller: _number,
          enabled: !state.submitting,
          onChanged: cubit.invoiceNumberChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: context.loc.invoiceNumberLabel,
          ),
        ),
        const Gap(12),
        TextField(
          controller: _recipient,
          enabled: !state.submitting,
          onChanged: cubit.recipientNameChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: context.loc.invoiceRecipientNameLabel,
          ),
        ),
        const Gap(20),
        Text(
          context.loc.invoiceExpiryDays(state.expiryDays),
          style: context.font.bodyLarge,
        ),
        Slider(
          value: state.expiryDays.toDouble(),
          min: 1,
          max: 7,
          divisions: 6,
          label: '${state.expiryDays}',
          onChanged: state.submitting
              ? null
              : (value) => cubit.expiryDaysChanged(value.round()),
        ),
        const Gap(12),
        TextField(
          controller: _memo,
          enabled: !state.submitting,
          onChanged: cubit.privateMemoChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: context.loc.invoicePrivateMemoLabel,
          ),
        ),
        const Gap(24),
        BBButton.big(
          label: state.submitting
              ? context.loc.invoiceCreatingButton
              : context.loc.invoiceCreateButton,
          onPressed: cubit.submit,
          disabled: state.submitting || !state.hasAnyRail,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
      ],
    );
  }

  Widget _currencyField(
    BuildContext context,
    InvoiceCreateState state,
    InvoiceCreateCubit cubit,
  ) {
    final errorText = state.invalidField == InvoiceCreateField.currency
        ? context.loc.invoiceCurrencyError
        : null;
    if (state.currenciesUnavailable || state.currencies.isEmpty) {
      return TextField(
        enabled: !state.submitting,
        onChanged: cubit.fiatCurrencyChanged,
        controller: TextEditingController(text: state.fiatCurrency),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: context.loc.invoiceCurrencyLabel,
          errorText: errorText,
        ),
      );
    }
    final codes = <String>{
      ...state.currencies.map((c) => c.code),
      if (state.fiatCurrency.isNotEmpty) state.fiatCurrency,
    }.toList();
    return DropdownButtonFormField<String>(
      initialValue: state.fiatCurrency.isEmpty ? null : state.fiatCurrency,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: context.loc.invoiceCurrencyLabel,
        errorText: errorText,
      ),
      items: [
        for (final code in codes)
          DropdownMenuItem(value: code, child: Text(code)),
      ],
      onChanged: state.submitting
          ? null
          : (value) {
              if (value != null) cubit.fiatCurrencyChanged(value);
            },
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
