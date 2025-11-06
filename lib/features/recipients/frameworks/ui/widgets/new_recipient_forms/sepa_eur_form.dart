import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SepaEurForm extends StatefulWidget {
  const SepaEurForm({super.key});

  @override
  _SepaEurFormState createState() => _SepaEurFormState();
}

class _SepaEurFormState extends State<SepaEurForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _ibanFocusNode = FocusNode();
  final FocusNode _firstnameFocusNode = FocusNode();
  final FocusNode _lastnameFocusNode = FocusNode();
  final FocusNode _corporateNameFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _iban = '';
  String _firstname = '';
  String _lastname = '';
  String _corporateName = '';
  String _label = '';
  bool _isCorporate = false;
  bool _isMyAccount = false;

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = SepaEurFormDataModel(
        iban: _iban,
        isCorporate: _isCorporate,
        isOwner: _isMyAccount,
        firstname: _isCorporate ? null : _firstname,
        lastname: _isCorporate ? null : _lastname,
        corporateName: _isCorporate ? _corporateName : null,
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
            labelText: 'IBAN',
            hintText: 'Enter IBAN',
            focusNode: _ibanFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) {
              if (_isCorporate) {
                _corporateNameFocusNode.requestFocus();
              } else {
                _firstnameFocusNode.requestFocus();
              }
            },
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? "This field can't be empty"
                        : null,
            onChanged: (value) {
              setState(() {
                _iban = value;
              });
            },
          ),
          const Gap(16.0),
          CheckboxListTile(
            title: const Text('Corporate account'),
            value: _isCorporate,
            onChanged: (value) {
              setState(() {
                _isCorporate = value ?? false;
                // Clear opposite fields when toggling
                if (_isCorporate) {
                  _firstname = '';
                  _lastname = '';
                } else {
                  _corporateName = '';
                }
              });
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const Gap(12.0),
          if (!_isCorporate) ...[
            BBTextFormField(
              labelText: 'First Name',
              hintText: 'Enter first name',
              focusNode: _firstnameFocusNode,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _lastnameFocusNode.requestFocus(),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? "This field can't be empty"
                          : null,
              onChanged: (value) {
                setState(() {
                  _firstname = value;
                });
              },
            ),
            const Gap(12.0),
            BBTextFormField(
              labelText: 'Last Name',
              hintText: 'Enter last name',
              focusNode: _lastnameFocusNode,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? "This field can't be empty"
                          : null,
              onChanged: (value) {
                setState(() {
                  _lastname = value;
                });
              },
            ),
            const Gap(12.0),
          ],
          if (_isCorporate) ...[
            BBTextFormField(
              labelText: 'Corporate Name',
              hintText: 'Enter corporate name',
              focusNode: _corporateNameFocusNode,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? "This field can't be empty"
                          : null,
              onChanged: (value) {
                setState(() {
                  _corporateName = value;
                });
              },
            ),
            const Gap(12.0),
          ],
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
          const Gap(16.0),
          Text(
            'Who does this account belong to?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.colour.onSurface,
            ),
          ),
          const Gap(8.0),
          RadioListTile<bool>(
            title: const Text('This is my account'),
            value: true,
            groupValue: _isMyAccount,
            onChanged: (value) {
              setState(() {
                _isMyAccount = value ?? true;
              });
            },
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          const Gap(8.0),
          RadioListTile<bool>(
            title: const Text("This is someone else's account"),
            value: false,
            groupValue: _isMyAccount,
            onChanged: (value) {
              setState(() {
                _isMyAccount = value ?? false;
              });
            },
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          const Gap(24.0),
          RecipientFormContinueButton(onPressed: _submitForm),
        ],
      ),
    );
  }
}
