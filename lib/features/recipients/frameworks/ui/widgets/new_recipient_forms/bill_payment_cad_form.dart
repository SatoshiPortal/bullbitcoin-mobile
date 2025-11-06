import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class BillPaymentCadForm extends StatefulWidget {
  const BillPaymentCadForm({super.key});

  @override
  _BillPaymentCadFormState createState() => _BillPaymentCadFormState();
}

class _BillPaymentCadFormState extends State<BillPaymentCadForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _billerSearchFocusNode = FocusNode();
  final FocusNode _accountNumberFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _billerSearch = '';
  String _payeeName = '';
  String _payeeCode = '';
  String _payeeAccountNumber = '';
  String _label = '';

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = BillPaymentCadFormDataModel(
        payeeName: _payeeName,
        payeeCode: _payeeCode,
        payeeAccountNumber: _payeeAccountNumber,
        label: _label.isEmpty ? null : _label,
      );

      context.read<RecipientsBloc>().add(RecipientsEvent.added(formData));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          BBTextFormField(
            labelText: 'Biller Search',
            prefix: Icon(Icons.search, color: context.colour.outline),
            hintText: 'Enter first 3 letters of biller name',
            focusNode: _billerSearchFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (_) {
              // TODO: Trigger biller search
            },
            validator: null, // Search field doesn't need validation
            onChanged: (value) {
              setState(() {
                _billerSearch = value;
              });
              // TODO: Trigger API search when length >= 3
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Biller Name',
            hintText: 'Selected biller name',
            disabled: true,
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? "Please select a biller"
                        : null,
            onChanged: (value) {
              setState(() {
                _payeeName = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Payee Account Number',
            hintText: 'Enter account number',
            focusNode: _accountNumberFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? "This field can't be empty"
                        : null,
            onChanged: (value) {
              setState(() {
                _payeeAccountNumber = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Label (optional)',
            hintText: 'Enter a label for this recipient',
            focusNode: _labelFocusNode,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitForm(),
            validator: null,
            onChanged: (value) {
              setState(() {
                _label = value;
              });
            },
          ),
          const Gap(24.0),
          RecipientFormContinueButton(onPressed: _submitForm),
        ],
      ),
    );
  }
}
