import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipient_form_submission.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class BankAccountArgentinaForm extends StatefulWidget {
  const BankAccountArgentinaForm({super.key, this.recipient, this.hookError});

  final RecipientViewModel? recipient;
  final String? hookError;

  @override
  BankAccountArgentinaFormState createState() =>
      BankAccountArgentinaFormState();
}

class BankAccountArgentinaFormState extends State<BankAccountArgentinaForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _cbuCvuFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _claveUniform = '';
  String _name = '';
  String _label = '';

  @override
  void initState() {
    super.initState();
    final recipient = widget.recipient;
    _claveUniform = recipient?.bankAccount ?? '';
    _name = recipient?.name ?? '';
    _label = recipient?.label ?? '';
  }

  @override
  void dispose() {
    _cbuCvuFocusNode.dispose();
    _nameFocusNode.dispose();
    _labelFocusNode.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = BankAccountArgentinaFormDataModel(
        claveUniform: _claveUniform,
        name: _name,
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
          BBTextFormField(
            initialValue: _claveUniform,
            labelText: context.loc.recipientsFieldCvuCbu,
            errorText: recipientUpdateFieldError(context, 'claveUniform'),
            hintText: context.loc.recipientsFieldCvuCbuHint,
            focusNode: _cbuCvuFocusNode,
            autofocus: true,
            textInputAction: .next,
            onFieldSubmitted: (_) => _nameFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _claveUniform = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            initialValue: _name,
            labelText: context.loc.recipientsFieldName,
            errorText: recipientUpdateFieldError(context, 'name'),
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
