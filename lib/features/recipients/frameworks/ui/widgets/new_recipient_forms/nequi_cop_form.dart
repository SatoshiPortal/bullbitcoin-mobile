import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/cop_document_type_label.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipient_form_submission.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cop_document_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class NequiCopForm extends StatefulWidget {
  const NequiCopForm({super.key, this.recipient, this.hookError});

  final RecipientViewModel? recipient;
  final String? hookError;

  @override
  NequiCopFormState createState() => NequiCopFormState();
}

class NequiCopFormState extends State<NequiCopForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _lastnameFocusNode = FocusNode();
  final FocusNode _corporateNameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _phoneNumber = '';
  CopDocumentType _documentType = CopDocumentType.cc;
  String _documentId = '';
  String _name = '';
  String _lastname = '';
  String _email = '';
  String _corporateName = '';
  String _label = '';
  bool _isCorporate = false;

  @override
  void initState() {
    super.initState();
    final recipient = widget.recipient;
    for (final documentType in CopDocumentType.values) {
      if (documentType.value == recipient?.documentType) {
        _documentType = documentType;
      }
    }
    _phoneNumber = recipient?.phoneNumber ?? recipient?.bankAccount ?? '';
    _documentId = recipient?.documentId ?? '';
    _name = recipient?.name ?? '';
    _lastname = recipient?.lastname ?? '';
    _email = recipient?.email ?? '';
    _corporateName = recipient?.corporateName ?? '';
    _label = recipient?.label ?? '';
    _isCorporate = recipient?.isCorporate ?? false;
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _lastnameFocusNode.dispose();
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
        name: _isCorporate ? null : _name,
        lastname: _isCorporate ? null : _lastname,
        email: _email,
        isCorporate: _isCorporate,
        corporateName: _isCorporate ? _corporateName : null,
        label: _label.isEmpty ? null : _label,
      );

      submitRecipientForm(context, formData, recipient: widget.recipient);
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
            initialValue: _phoneNumber,
            labelText: context.loc.recipientsFieldPhoneNumber,
            errorText:
                recipientUpdateFieldError(context, 'bankAccount') ??
                recipientUpdateFieldError(context, 'phoneNumber'),
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
          Material(
            elevation: 4,
            shadowColor: context.appColors.onSurface.withValues(alpha: 0.7),
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(4.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButton<CopDocumentType>(
                isExpanded: true,
                alignment: Alignment.centerLeft,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(4.0),
                dropdownColor: context.appColors.surface,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.appColors.onSurface,
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
            initialValue: _documentId,
            labelText: copDocumentTypeRecipientNumberLabel(
              context,
              _documentType,
            ),
            errorText: recipientUpdateFieldError(context, 'documentId'),
            hintText: context.loc.recipientsFieldDocumentNumberHint,
            textInputAction: .next,
            onFieldSubmitted: (_) => _isCorporate
                ? _corporateNameFocusNode.requestFocus()
                : _nameFocusNode.requestFocus(),
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
          CheckboxListTile(
            title: Text(context.loc.recipientsFieldCorporateAccount),
            value: _isCorporate,
            onChanged: (value) {
              setState(() => _isCorporate = value ?? false);
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: .leading,
          ),
          const Gap(12.0),
          if (_isCorporate)
            BBTextFormField(
              key: const ValueKey('nequi-corporate-name'),
              initialValue: _corporateName,
              labelText: context.loc.recipientsFieldCorporateName,
              hintText: context.loc.recipientsFieldCorporateNameHint,
              errorText: recipientUpdateFieldError(context, 'corporateName'),
              focusNode: _corporateNameFocusNode,
              textInputAction: .next,
              onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.loc.recipientsValidationFieldRequired
                  : null,
              onChanged: (value) => _corporateName = value,
            )
          else ...[
            BBTextFormField(
              key: const ValueKey('nequi-first-name'),
              initialValue: _name,
              labelText: context.loc.recipientsFieldFirstName,
              hintText: context.loc.recipientsFieldFirstNameHint,
              errorText: recipientUpdateFieldError(context, 'name'),
              focusNode: _nameFocusNode,
              textInputAction: .next,
              onFieldSubmitted: (_) => _lastnameFocusNode.requestFocus(),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.loc.recipientsValidationFieldRequired
                  : null,
              onChanged: (value) => _name = value,
            ),
            const Gap(12.0),
            BBTextFormField(
              key: const ValueKey('nequi-last-name'),
              initialValue: _lastname,
              labelText: context.loc.recipientsFieldLastName,
              hintText: context.loc.recipientsFieldLastNameHint,
              errorText: recipientUpdateFieldError(context, 'lastname'),
              focusNode: _lastnameFocusNode,
              textInputAction: .next,
              onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.loc.recipientsValidationFieldRequired
                  : null,
              onChanged: (value) => _lastname = value,
            ),
          ],
          const Gap(12.0),
          BBTextFormField(
            initialValue: _email,
            labelText: context.loc.recipientsFieldEmailAddress,
            hintText: context.loc.recipientsFieldEmailAddressHint,
            errorText: recipientUpdateFieldError(context, 'email'),
            focusNode: _emailFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) => _email = value,
          ),
          const Gap(12.0),
          BBTextFormField(
            initialValue: _label,
            labelText: context.loc.recipientsLabelOptional,
            errorText: recipientUpdateFieldError(context, 'label'),
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
            isEditing: widget.recipient != null,
          ),
        ],
      ),
    );
  }
}
