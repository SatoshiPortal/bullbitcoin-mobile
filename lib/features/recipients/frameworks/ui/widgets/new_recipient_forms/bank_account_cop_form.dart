import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/cop_document_type_label.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cop_bank_account_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cop_bank_institution.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cop_document_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class BankAccountCopForm extends StatefulWidget {
  const BankAccountCopForm({super.key, this.hookError});

  final String? hookError;

  @override
  BankAccountCopFormState createState() => BankAccountCopFormState();
}

class BankAccountCopFormState extends State<BankAccountCopForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _accountNumberFocusNode = FocusNode();
  final FocusNode _documentIdFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  CopBankInstitution? _institutionNumber;
  CopBankAccountType _accountType = CopBankAccountType.savings;
  String _accountNumber = '';
  CopDocumentType _documentType = CopDocumentType.cc;
  String _documentId = '';
  String _name = '';
  String _label = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _accountNumberFocusNode.dispose();
    _documentIdFocusNode.dispose();
    _nameFocusNode.dispose();
    _labelFocusNode.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = PseColombiaFormDataModel(
        bankCode: _institutionNumber!.code,
        accountType: _accountType.value,
        bankAccount: _accountNumber,
        documentType: _documentType.value,
        documentId: _documentId,
        name: _name,
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
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          // Institution Number Dropdown
          Text(
            context.loc.recipientsFieldBankInstitution,
            style: TextStyle(
              fontSize: 14,
              fontWeight: .w500,
              color: context.appColors.onSurface,
            ),
            textAlign: .left,
          ),
          const Gap(8.0),
          Material(
            elevation: 4,
            color: context.appColors.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButtonFormField<CopBankInstitution?>(
                isExpanded: true,
                alignment: Alignment.centerLeft,
                borderRadius: BorderRadius.circular(4.0),
                decoration: const InputDecoration(border: InputBorder.none),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.appColors.secondary,
                ),
                initialValue: _institutionNumber,
                onChanged: (value) {
                  setState(() {
                    _institutionNumber = value;
                  });
                },
                validator: (v) => (v == null)
                    ? context.loc.recipientsValidationBankInstitution
                    : null,
                items: [
                  DropdownMenuItem<CopBankInstitution?>(
                    value: null,
                    child: Text(
                      context.loc.recipientsFieldBankInstitutionPlaceholder,
                    ),
                  ),
                  ...CopBankInstitution.values.map((institution) {
                    return DropdownMenuItem<CopBankInstitution>(
                      value: institution,
                      child: Text(switch (institution) {
                        CopBankInstitution.bancolombia =>
                          'Bancolombia (${institution.code})',
                      }),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Gap(12.0),
          // Account Type Dropdown
          Text(
            context.loc.recipientsFieldAccountType,
            style: TextStyle(
              fontSize: 14,
              fontWeight: .w500,
              color: context.appColors.onSurface,
            ),
            textAlign: .left,
          ),
          const Gap(8.0),
          Material(
            elevation: 4,
            color: context.appColors.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButton<CopBankAccountType>(
                isExpanded: true,
                alignment: Alignment.centerLeft,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(4.0),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.appColors.secondary,
                ),
                value: _accountType,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _accountType = value;
                  });
                },
                items: [
                  ...CopBankAccountType.values.map((type) {
                    return DropdownMenuItem<CopBankAccountType>(
                      value: type,
                      child: Text(switch (type) {
                        CopBankAccountType.savings =>
                          context.loc.recipientsAccountTypeSavings,
                        CopBankAccountType.checking =>
                          context.loc.recipientsAccountTypeChecking,
                      }),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsFieldBankAccountNumber,
            hintText: context.loc.recipientsFieldBankAccountNumberHint,
            focusNode: _accountNumberFocusNode,
            autofocus: true,
            textInputAction: .next,
            onFieldSubmitted: (_) => _documentIdFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _accountNumber = value;
              });
            },
          ),
          const Gap(12.0), // Account Type Dropdown
          Text(
            context.loc.recipientsFieldDocumentType,
            style: TextStyle(
              fontSize: 14,
              fontWeight: .w500,
              color: context.appColors.onSurface,
            ),
            textAlign: .left,
          ),
          const Gap(8.0),
          Material(
            elevation: 4,
            color: context.appColors.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButton<CopDocumentType>(
                isExpanded: true,
                alignment: Alignment.centerLeft,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(4.0),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.appColors.secondary,
                ),
                value: _documentType,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _documentType = value;
                  });
                },
                items: [
                  ...CopDocumentType.values.map((type) {
                    return DropdownMenuItem<CopDocumentType>(
                      value: type,
                      child: Text(copDocumentTypeLabel(context, type)),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: copDocumentTypeLabel(context, _documentType),
            hintText: context.loc.recipientsFieldDocumentNumberHint,
            focusNode: _documentIdFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _nameFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _documentId = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsFieldRecipientNameLabel,
            hintText: context.loc.recipientsFieldNameHint,
            focusNode: _nameFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _name = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsLabelOptional,
            hintText: context.loc.recipientsLabelHint,
            focusNode: _labelFocusNode,
            textInputAction: .done,
            onFieldSubmitted: (_) => _submitForm(),
            validator: null,
            onChanged: (value) {
              setState(() {
                _label = value;
              });
            },
          ),
          const Gap(24.0),
          RecipientFormContinueButton(
            onPressed: _submitForm,
            hookError: widget.hookError,
          ),
        ],
      ),
    );
  }
}
