import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/cop_document_type_label.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cop_document_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';

class NequiCopForm extends StatefulWidget {
  const NequiCopForm({super.key, this.hookError});

  final String? hookError;

  @override
  NequiCopFormState createState() => NequiCopFormState();
}

class NequiCopFormState extends State<NequiCopForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _phoneNumber = '';
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
    _nameFocusNode.dispose();
    _labelFocusNode.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = NequiColombiaFormDataModel(
        phoneNumber: _phoneNumber,
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
          // Phone Number
          BBTextFormField(
            labelText: context.loc.recipientsFieldPhoneNumber,
            hintText: context.loc.recipientsFieldPhoneNumberHint,
            autofocus: true,
            prefixText: '+57',
            textInputAction: .next,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _phoneNumber = value;
              });
            },
          ),
          const Gap(12.0), // Account Type Dropdown
          Text(
            context.loc.recipientsFieldDocumentType,
            style: context.font.bodyLarge?.copyWith(
              color: context.appColors.secondary,
              fontWeight: .w500,
            ),
            textAlign: .left,
          ),
          const Gap(8.0),
          BullDropdown<CopDocumentType>(
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
          const Gap(12.0),
          BBTextFormField(
            labelText: copDocumentTypeRecipientNumberLabel(
              context,
              _documentType,
            ),
            hintText: context.loc.recipientsFieldDocumentNumberHint,
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
