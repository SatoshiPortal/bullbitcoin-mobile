import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/lowercase_input_formatter.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipient_form_submission.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class InteracEmailCadForm extends StatefulWidget {
  const InteracEmailCadForm({super.key, this.recipient, this.hookError});

  final RecipientViewModel? recipient;
  final String? hookError;

  @override
  InteracEmailCadFormState createState() => InteracEmailCadFormState();
}

class InteracEmailCadFormState extends State<InteracEmailCadForm> {
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
    _onlyOwnerPermitted = context
        .read<RecipientsBloc>()
        .state
        .onlyOwnerRecipients;
    final recipient = widget.recipient;
    _email = recipient?.email ?? '';
    _name = recipient?.name ?? '';
    _securityQuestion = recipient?.securityQuestion ?? '';
    _securityAnswer = recipient?.securityAnswer ?? '';
    _label = recipient?.label ?? '';
    _isMyAccount = recipient?.isOwner ?? _onlyOwnerPermitted;
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
        securityQuestion: _securityQuestion.trim().isEmpty
            ? null
            : _securityQuestion,
        securityAnswer: _securityAnswer.trim().isEmpty ? null : _securityAnswer,
        isOwner: _isMyAccount,
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
            initialValue: _email,
            labelText: context.loc.recipientsFieldEmailAddress,
            hintText: context.loc.recipientsFieldEmailAddressHint,
            errorText: recipientUpdateFieldError(context, 'email'),
            focusNode: _emailFocusNode,
            autofocus: true,
            inputFormatters: [
              // No whitespace allowed
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
              // Force lowercase
              LowerCaseTextFormatter(),
            ],
            textInputAction: .next,
            onFieldSubmitted: (_) => _nameFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _email = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            initialValue: _name,
            labelText: context.loc.recipientsFieldName,
            hintText: context.loc.recipientsFieldNameHint,
            errorText: recipientUpdateFieldError(context, 'name'),
            focusNode: _nameFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => widget.recipient == null
                ? _labelFocusNode.requestFocus()
                : _securityQuestionFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _name = value;
              });
            },
          ),
          if (widget.recipient != null) ...[
            const Gap(12.0),
            BBTextFormField(
              initialValue: _securityQuestion,
              labelText: context.loc.recipientsFieldSecurityQuestion,
              hintText: context.loc.withdrawInteracSecurityQuestionLengthError,
              errorText: recipientUpdateFieldError(context, 'securityQuestion'),
              focusNode: _securityQuestionFocusNode,
              textInputAction: .next,
              onFieldSubmitted: (_) => _securityAnswerFocusNode.requestFocus(),
              validator: _validateSecurityQuestion,
              onChanged: (value) {
                setState(() => _securityQuestion = value);
              },
            ),
            const Gap(12.0),
            BBTextFormField(
              initialValue: _securityAnswer,
              labelText: context.loc.recipientsFieldSecurityAnswer,
              hintText: context.loc.withdrawInteracSecurityAnswerFormatError,
              errorText: recipientUpdateFieldError(context, 'securityAnswer'),
              focusNode: _securityAnswerFocusNode,
              textInputAction: .next,
              onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
              enableSuggestions: false,
              autocorrect: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              validator: _validateSecurityAnswer,
              onChanged: (value) {
                setState(() => _securityAnswer = value);
              },
            ),
          ],
          const Gap(12.0),
          BBTextFormField(
            initialValue: _label,
            labelText: context.loc.recipientsLabelOptional,
            hintText: context.loc.recipientsLabelHint,
            errorText: recipientUpdateFieldError(context, 'label'),
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
          const Gap(16.0),
          Text(
            context.loc.recipientsAccountOwnerQuestion,
            style: TextStyle(
              fontSize: 14,
              fontWeight: .w500,
              color: context.appColors.onSurface,
            ),
          ),
          const Gap(8.0),
          RadioGroup<bool>(
            groupValue: _isMyAccount,
            onChanged: (value) {
              if (!_onlyOwnerPermitted) {
                setState(() {
                  _isMyAccount = value ?? false;
                });
              }
            },
            child: Column(
              children: [
                RadioListTile<bool>(
                  title: Text(context.loc.recipientsAccountOwnerMine),
                  value: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                const Gap(8.0),
                RadioListTile<bool>(
                  title: Text(context.loc.recipientsAccountOwnerSomeoneElse),
                  value: false,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
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

  String? _validateSecurityQuestion(String? value) {
    final question = value?.trim() ?? '';
    final answer = _securityAnswer.trim();
    if (question.isEmpty && answer.isEmpty) return null;
    if (question.isEmpty) return context.loc.recipientsValidationFieldRequired;
    if (question.length < 3 || question.length > 40) {
      return context.loc.withdrawInteracSecurityQuestionLengthError;
    }
    return null;
  }

  String? _validateSecurityAnswer(String? value) {
    final question = _securityQuestion.trim();
    final answer = value?.trim() ?? '';
    if (question.isEmpty && answer.isEmpty) return null;
    if (answer.isEmpty) return context.loc.recipientsValidationFieldRequired;
    if (answer.length < 3 || answer.length > 40) {
      return context.loc.withdrawInteracSecurityAnswerLengthError;
    }
    if (!RegExp(r'^[a-zA-ZÀ-ž0-9\-]*$').hasMatch(answer)) {
      return context.loc.withdrawInteracSecurityAnswerFormatError;
    }
    return null;
  }
}
