import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class BankTransferCadForm extends StatefulWidget {
  const BankTransferCadForm({super.key});

  @override
  _BankTransferCadFormState createState() => _BankTransferCadFormState();
}

class _BankTransferCadFormState extends State<BankTransferCadForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _institutionNumberFocusNode = FocusNode();
  final FocusNode _transitNumberFocusNode = FocusNode();
  final FocusNode _accountNumberFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _defaultCommentFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _institutionNumber = '';
  String _transitNumber = '';
  String _accountNumber = '';
  String _name = '';
  String _defaultComment = '';
  String _label = '';
  bool _isMyAccount = false;

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = BankTransferCadFormDataModel(
        institutionNumber: _institutionNumber,
        transitNumber: _transitNumber,
        accountNumber: _accountNumber,
        name: _name,
        isOwner: _isMyAccount,
        defaultComment: _defaultComment.isEmpty ? null : _defaultComment,
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
            labelText: 'Institution Number',
            hintText: 'Enter institution number',
            focusNode: _institutionNumberFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _transitNumberFocusNode.requestFocus(),
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? "This field can't be empty"
                        : null,
            onChanged: (value) {
              setState(() {
                _institutionNumber = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Transit Number',
            hintText: 'Enter transit number',
            focusNode: _transitNumberFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _accountNumberFocusNode.requestFocus(),
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? "This field can't be empty"
                        : null,
            onChanged: (value) {
              setState(() {
                _transitNumber = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Account Number',
            hintText: 'Enter account number',
            focusNode: _accountNumberFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _nameFocusNode.requestFocus(),
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? "This field can't be empty"
                        : null,
            onChanged: (value) {
              setState(() {
                _accountNumber = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Name',
            hintText: 'Enter recipient name',
            focusNode: _nameFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _defaultCommentFocusNode.requestFocus(),
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
            labelText: 'Default Comment (optional)',
            hintText: 'Enter default comment',
            focusNode: _defaultCommentFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator: null,
            onChanged: (value) {
              setState(() {
                _defaultComment = value;
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
