import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
  final FocusNode _firstNameFocusNode = FocusNode();
  final FocusNode _lastNameFocusNode = FocusNode();
  final FocusNode _corporateNameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _phoneNumber = '';
  CopDocumentTypeViewModel _documentType = CopDocumentTypeViewModel.cc;
  String _documentId = '';
  bool _isCorporate = false;
  String _firstName = '';
  String _lastName = '';
  String _corporateName = '';
  String _email = '';
  String _label = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _corporateNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _labelFocusNode.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = NequiColombiaFormDataModel(
        phoneNumber: _phoneNumber,
        documentType: _documentType.value,
        documentId: _documentId,
        isCorporate: _isCorporate,
        name: _isCorporate ? null : _firstName,
        lastname: _isCorporate ? null : _lastName,
        corporateName: _isCorporate ? _corporateName : null,
        email: _email,
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
            labelText: context.loc.recipientPhoneNumber,
            hintText: context.loc.recipientPhoneNumberHint,
            autofocus: true,
            prefixText: '+57',
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _phoneNumber = value;
              });
            },
          ),
          const Gap(12.0),
          // Document Type Dropdown
          Text(
            context.loc.recipientIdDocumentType,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.appColors.onSurface,
            ),
            textAlign: TextAlign.left,
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
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _firstNameFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _documentId = value;
              });
            },
          ),
          const Gap(12.0),
          // Corporate account toggle
          Row(
            children: [
              Checkbox(
                value: _isCorporate,
                onChanged: (value) {
                  setState(() {
                    _isCorporate = value ?? false;
                  });
                },
              ),
              Text(
                context.loc.recipientIsCorporateAccount,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.appColors.onSurface,
                ),
              ),
            ],
          ),
          const Gap(12.0),
          if (_isCorporate)
            BBTextFormField(
              labelText: context.loc.recipientCorporateName,
              hintText: context.loc.recipientCorporateNameHint,
              focusNode: _corporateNameFocusNode,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.loc.recipientFieldRequired
                  : null,
              onChanged: (value) {
                setState(() {
                  _corporateName = value;
                });
              },
            )
          else ...[
            BBTextFormField(
              labelText: context.loc.recipientFirstName,
              hintText: context.loc.recipientFirstNameHint,
              focusNode: _firstNameFocusNode,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _lastNameFocusNode.requestFocus(),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.loc.recipientFieldRequired
                  : null,
              onChanged: (value) {
                setState(() {
                  _firstName = value;
                });
              },
            ),
            const Gap(12.0),
            BBTextFormField(
              labelText: context.loc.recipientLastName,
              hintText: context.loc.recipientLastNameHint,
              focusNode: _lastNameFocusNode,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.loc.recipientFieldRequired
                  : null,
              onChanged: (value) {
                setState(() {
                  _lastName = value;
                });
              },
            ),
          ],
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientEmail,
            hintText: context.loc.recipientEmailHint,
            focusNode: _emailFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return context.loc.recipientFieldRequired;
              final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
              if (!emailRegex.hasMatch(v.trim())) return context.loc.recipientInvalidEmail;
              return null;
            },
            onChanged: (value) {
              setState(() {
                _email = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientLabelOptional,
            hintText: context.loc.recipientLabelHint,
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
