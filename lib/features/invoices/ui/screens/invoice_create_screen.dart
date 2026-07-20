import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_create_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_create_state.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_failure_l10n.dart';
import 'package:bb_mobile/features/invoices/ui/widgets/private_invoice_link_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_entry_tile.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class InvoiceCreateScreen extends StatefulWidget {
  const InvoiceCreateScreen({super.key});

  @override
  State<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends State<InvoiceCreateScreen> {
  final _amount = TextEditingController();
  final _details = <InvoiceCreateField, TextEditingController>{
    for (final field in InvoiceCreateField.values)
      if (field != InvoiceCreateField.amount &&
          field != InvoiceCreateField.currency &&
          field != InvoiceCreateField.details)
        field: TextEditingController(),
  };
  bool _detailsExpanded = false;

  @override
  void dispose() {
    _amount.dispose();
    for (final controller in _details.values) {
      controller.dispose();
    }
    super.dispose();
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
            child: state.initializing
                ? const Center(child: CircularProgressIndicator())
                : state.isSubmitted
                ? _success(context, state)
                : state.pendingRetry
                ? _pending(context, state)
                : _form(context, state),
          ),
        );
      },
    );
  }

  Widget _success(BuildContext context, InvoiceCreateState state) {
    final link = state.result!.privateLink.value;
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
        PrivateInvoiceLinkActions(link: link),
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

  Widget _pending(BuildContext context, InvoiceCreateState state) {
    final cubit = context.read<InvoiceCreateCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.loc.invoicePendingCreateMessage,
              textAlign: TextAlign.center,
            ),
            const Gap(16),
            BBButton.big(
              label: state.submitting
                  ? context.loc.invoiceCreatingButton
                  : context.loc.invoiceRetryPendingCreate,
              onPressed: cubit.retryPending,
              disabled: state.submitting,
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
            ),
          ],
        ),
      ),
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            state.populatedFieldCount == 0
                ? context.loc.invoiceAddDetails
                : context.loc.invoiceDetailsFieldCount(
                    state.populatedFieldCount,
                  ),
          ),
          trailing: Icon(
            _detailsExpanded ? Icons.expand_less : Icons.expand_more,
          ),
          onTap: state.submitting
              ? null
              : () => setState(() => _detailsExpanded = !_detailsExpanded),
        ),
        if (_detailsExpanded) ...[
          const Gap(8),
          _detailsForm(context, state, cubit),
        ],
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
        const Gap(16),
        // Account-scoped: applies to invoices created afterward.
        const FiatSettlementEntryTile(product: FiatSettlementProduct.invoice),
      ],
    );
  }

  Widget _detailsForm(
    BuildContext context,
    InvoiceCreateState state,
    InvoiceCreateCubit cubit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(context, context.loc.invoicePayerSection),
        _field(context, state, cubit, InvoiceCreateField.payerName),
        _field(context, state, cubit, InvoiceCreateField.payerCorporateName),
        _field(
          context,
          state,
          cubit,
          InvoiceCreateField.payerAddress,
          multiline: true,
        ),
        _field(context, state, cubit, InvoiceCreateField.payerEmail),
        _field(context, state, cubit, InvoiceCreateField.payerPhone),
        _heading(context, context.loc.invoiceDetailsSection),
        _field(
          context,
          state,
          cubit,
          InvoiceCreateField.description,
          multiline: true,
        ),
        _field(context, state, cubit, InvoiceCreateField.invoiceNumber),
        _field(
          context,
          state,
          cubit,
          InvoiceCreateField.purchaseOrderReference,
        ),
        _dateField(context, state, cubit, InvoiceCreateField.invoiceDate),
        _dateField(context, state, cubit, InvoiceCreateField.paymentDeadline),
        _heading(context, context.loc.invoicePayeeSection),
        _field(context, state, cubit, InvoiceCreateField.payeeName),
        _field(context, state, cubit, InvoiceCreateField.payeeCorporateName),
        _field(
          context,
          state,
          cubit,
          InvoiceCreateField.payeeAddress,
          multiline: true,
        ),
        _field(context, state, cubit, InvoiceCreateField.payeeEmail),
        _field(context, state, cubit, InvoiceCreateField.payeePhone),
      ],
    );
  }

  Widget _heading(BuildContext context, String value) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(value, style: context.font.titleMedium),
  );

  Widget _field(
    BuildContext context,
    InvoiceCreateState state,
    InvoiceCreateCubit cubit,
    InvoiceCreateField field, {
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _details[field],
        enabled: !state.submitting,
        minLines: multiline ? 2 : 1,
        maxLines: multiline ? 4 : 1,
        keyboardType: switch (field) {
          InvoiceCreateField.payerEmail ||
          InvoiceCreateField.payeeEmail => TextInputType.emailAddress,
          InvoiceCreateField.payerPhone ||
          InvoiceCreateField.payeePhone => TextInputType.phone,
          _ => TextInputType.text,
        },
        onChanged: (value) => cubit.detailChanged(field, value),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: _label(context, field),
          errorText: state.invalidField == field
              ? context.loc.invoiceDetailsFieldError
              : null,
        ),
      ),
    );
  }

  Widget _dateField(
    BuildContext context,
    InvoiceCreateState state,
    InvoiceCreateCubit cubit,
    InvoiceCreateField field,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _details[field],
        enabled: !state.submitting,
        readOnly: true,
        onTap: () => _pickDate(context, cubit, field),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: _label(context, field),
          suffixIcon: _details[field]!.text.isEmpty
              ? const Icon(Icons.calendar_today)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: state.submitting
                      ? null
                      : () => cubit.detailChanged(field, ''),
                ),
          errorText: state.invalidField == field
              ? context.loc.invoiceDetailsFieldError
              : null,
        ),
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    InvoiceCreateCubit cubit,
    InvoiceCreateField field,
  ) async {
    final current = DateTime.tryParse(_details[field]!.text);
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100, 12, 31),
    );
    if (value == null) return;
    final encoded =
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    cubit.detailChanged(field, encoded);
  }

  String _label(BuildContext context, InvoiceCreateField field) =>
      switch (field) {
        InvoiceCreateField.payerName ||
        InvoiceCreateField.payeeName => context.loc.invoiceContactNameLabel,
        InvoiceCreateField.payerCorporateName ||
        InvoiceCreateField.payeeCorporateName =>
          context.loc.invoiceCorporateNameLabel,
        InvoiceCreateField.payerAddress || InvoiceCreateField.payeeAddress =>
          context.loc.invoiceContactAddressLabel,
        InvoiceCreateField.payerEmail ||
        InvoiceCreateField.payeeEmail => context.loc.invoiceContactEmailLabel,
        InvoiceCreateField.payerPhone ||
        InvoiceCreateField.payeePhone => context.loc.invoiceContactPhoneLabel,
        InvoiceCreateField.description =>
          context.loc.invoicePrivateDescriptionLabel,
        InvoiceCreateField.invoiceNumber => context.loc.invoiceNumberLabel,
        InvoiceCreateField.purchaseOrderReference =>
          context.loc.invoicePurchaseOrderLabel,
        InvoiceCreateField.invoiceDate => context.loc.invoiceDateLabel,
        InvoiceCreateField.paymentDeadline =>
          context.loc.invoicePaymentDeadlineLabel,
        _ => '',
      };

  Widget _currencyField(
    BuildContext context,
    InvoiceCreateState state,
    InvoiceCreateCubit cubit,
  ) {
    final errorText = state.invalidField == InvoiceCreateField.currency
        ? context.loc.invoiceCurrencyError
        : null;
    if (state.currenciesUnavailable || state.currencies.isEmpty) {
      return TextFormField(
        initialValue: state.fiatCurrency,
        enabled: !state.submitting,
        onChanged: cubit.fiatCurrencyChanged,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: context.loc.invoiceCurrencyLabel,
          errorText: errorText,
        ),
      );
    }
    final codes = <String>{
      ...state.currencies.map((currency) => currency.code),
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

  void _sync(InvoiceCreateState state) {
    _set(_amount, state.amountInput);
    final values = <InvoiceCreateField, String>{
      InvoiceCreateField.payerName: state.payerName,
      InvoiceCreateField.payerCorporateName: state.payerCorporateName,
      InvoiceCreateField.payerAddress: state.payerAddress,
      InvoiceCreateField.payerEmail: state.payerEmail,
      InvoiceCreateField.payerPhone: state.payerPhone,
      InvoiceCreateField.description: state.description,
      InvoiceCreateField.invoiceNumber: state.invoiceNumber,
      InvoiceCreateField.purchaseOrderReference: state.purchaseOrderReference,
      InvoiceCreateField.invoiceDate: state.invoiceDate,
      InvoiceCreateField.paymentDeadline: state.paymentDeadline,
      InvoiceCreateField.payeeName: state.payeeName,
      InvoiceCreateField.payeeCorporateName: state.payeeCorporateName,
      InvoiceCreateField.payeeAddress: state.payeeAddress,
      InvoiceCreateField.payeeEmail: state.payeeEmail,
      InvoiceCreateField.payeePhone: state.payeePhone,
    };
    for (final entry in values.entries) {
      _set(_details[entry.key]!, entry.value);
    }
  }

  void _set(TextEditingController controller, String value) {
    if (controller.text != value) controller.text = value;
  }
}
