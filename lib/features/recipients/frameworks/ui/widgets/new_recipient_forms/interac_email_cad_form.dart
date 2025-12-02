import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/lowercase_input_formatter.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class InteracEmailCadForm extends StatefulWidget {
  const InteracEmailCadForm({super.key});

  @override
  _InteracEmailCadFormState createState() => _InteracEmailCadFormState();
}

class _InteracEmailCadFormState extends State<InteracEmailCadForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _securityQuestionFocusNode = FocusNode();
  final FocusNode _securityAnswerFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _email = '';
  String _name = '';
  String _securityQuestion = '';
  String _securityAnswer = '';
  String _label = '';
  bool _isMyAccount = false;
  late bool _onlyOwnerPermitted;

  @override
  void initState() {
    super.initState();
    _onlyOwnerPermitted =
        context.read<RecipientsBloc>().state.onlyOwnerRecipients;
    if (_onlyOwnerPermitted) {
      _isMyAccount = true;
    }
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _nameFocusNode.dispose();
    _securityQuestionFocusNode.dispose();
    _securityAnswerFocusNode.dispose();
    _labelFocusNode.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = InteracEmailCadFormDataModel(
        email: _email,
        name: _name,
        securityQuestion: _securityQuestion,
        securityAnswer: _securityAnswer,
        isOwner: _isMyAccount,
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
            labelText: 'Email Address',
            hintText: 'Enter email address',
            focusNode: _emailFocusNode,
            autofocus: true,
            inputFormatters: [
              // No whitespace allowed
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
              // Force lowercase
              LowerCaseTextFormatter(),
            ],
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _nameFocusNode.requestFocus(),
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? "This field can't be empty"
                        : null,
            onChanged: (value) {
              setState(() {
                _email = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Name',
            hintText: 'Enter recipient name',
            focusNode: _nameFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _securityQuestionFocusNode.requestFocus(),
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
            labelText: 'Security Question',
            hintText: 'Enter security question (10-40 characters)',
            focusNode: _securityQuestionFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _securityAnswerFocusNode.requestFocus(),
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return "This field can't be empty";
              }
              if (v.trim().length < 10) {
                return "Security question must be at least 10 characters";
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _securityQuestion = value;
              });
            },
          ),
          if (_securityQuestion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${_securityQuestion.length}/40 characters',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      _securityQuestion.length < 10
                          ? context.colour.error
                          : context.colour.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Security Answer',
            hintText: 'Enter security answer',
            focusNode: _securityAnswerFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? "This field can't be empty"
                        : null,
            onChanged: (value) {
              setState(() {
                _securityAnswer = value;
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
            onChanged:
                _onlyOwnerPermitted
                    ? null
                    : (value) {
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
