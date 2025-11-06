import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SpeiSmsMxnForm extends StatefulWidget {
  const SpeiSmsMxnForm({super.key});

  @override
  _SpeiSmsMxnFormState createState() => _SpeiSmsMxnFormState();
}

class _SpeiSmsMxnFormState extends State<SpeiSmsMxnForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _institutionCodeFocusNode = FocusNode();
  final FocusNode _phoneNumberFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _institutionCode = '';
  String _phoneNumber = '';
  String _name = '';
  String _label = '';

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = SpeiSmsMxnFormDataModel(
        institutionCode: _institutionCode,
        phone: _phoneNumber,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          BBTextFormField(
            labelText: 'Institution Code',
            hintText: 'Enter institution code',
            focusNode: _institutionCodeFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _phoneNumberFocusNode.requestFocus(),
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? "This field can't be empty"
                        : null,
            onChanged: (value) {
              setState(() {
                _institutionCode = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Phone Number',
            hintText: 'Enter phone number',
            focusNode: _phoneNumberFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _nameFocusNode.requestFocus(),
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? "This field can't be empty"
                        : null,
            onChanged: (value) {
              setState(() {
                _phoneNumber = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Name',
            hintText: 'Enter recipient name',
            focusNode: _nameFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
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
