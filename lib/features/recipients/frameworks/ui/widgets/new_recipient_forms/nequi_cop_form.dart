import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cop_document_type_view_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class NequiCopForm extends StatefulWidget {
  const NequiCopForm({super.key});

  @override
  NequiCopFormState createState() => NequiCopFormState();
}

class NequiCopFormState extends State<NequiCopForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _phoneNumber = '';
  CopDocumentTypeViewModel _documentType = CopDocumentTypeViewModel.cc;
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
            labelText: 'Phone Number',
            hintText: 'Enter phone number',
            autofocus: true,
            prefixText: '+57',
            textInputAction: .next,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? "This field can't be empty"
                : null,
            onChanged: (value) {
              setState(() {
                _phoneNumber = value;
              });
            },
          ),
          const Gap(12.0), // Account Type Dropdown
          Text(
            'ID Document Type',
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
              child: DropdownButton<CopDocumentTypeViewModel>(
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
                  ...CopDocumentTypeViewModel.values.map((type) {
                    return DropdownMenuItem<CopDocumentTypeViewModel>(
                      value: type,
                      child: Text(switch (type) {
                        CopDocumentTypeViewModel.cc => 'Cédula de Ciudadanía',
                        CopDocumentTypeViewModel.ce => 'Cédula de Extranjería',
                        CopDocumentTypeViewModel.nit =>
                          'Número de Identificación Tributaria',
                        CopDocumentTypeViewModel.passport => 'Passport',
                        CopDocumentTypeViewModel.ti => 'Tarjeta de Identidad',
                        CopDocumentTypeViewModel.registroCivil =>
                          'Registro Civil',
                      }),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: switch (_documentType) {
              CopDocumentTypeViewModel.cc => 'Cédula de Ciudadanía',
              CopDocumentTypeViewModel.ce => 'Cédula de Extranjería',
              CopDocumentTypeViewModel.nit =>
                'Número de Identificación Tributaria',
              CopDocumentTypeViewModel.passport => 'Passport',
              CopDocumentTypeViewModel.ti => 'Tarjeta de Identidad',
              CopDocumentTypeViewModel.registroCivil => 'Registro Civil',
            },
            hintText: 'Enter document number',
            textInputAction: .next,
            onFieldSubmitted: (_) => _nameFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? "This field can't be empty"
                : null,
            onChanged: (value) {
              setState(() {
                _documentId = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Name of the recipient',
            hintText: "Enter recipient name",
            focusNode: _nameFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? "This field can't be empty"
                : null,
            onChanged: (value) {
              setState(() {
                _name = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Label (optional)',
            hintText: 'Enter a label for this recipient',
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
          RecipientFormContinueButton(onPressed: _submitForm),
        ],
      ),
    );
  }
}
