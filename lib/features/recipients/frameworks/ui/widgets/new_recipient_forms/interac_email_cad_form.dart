import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
  const InteracEmailCadForm({super.key, this.hookError});

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
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          BBTextFormField(
            labelText: context.loc.recipientsFieldEmailAddress,
            hintText: context.loc.recipientsFieldEmailAddressHint,
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
            labelText: context.loc.recipientsFieldName,
            hintText: context.loc.recipientsFieldNameHint,
            focusNode: _nameFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _securityQuestionFocusNode.requestFocus(),
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
            labelText: context.loc.recipientsFieldSecurityQuestion,
            hintText: context.loc.recipientsFieldSecurityQuestionHint,
            focusNode: _securityQuestionFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _securityAnswerFocusNode.requestFocus(),
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return context.loc.recipientsValidationFieldRequired;
              }
              if (v.trim().length < 10) {
                return context.loc.recipientsValidationSecurityQuestionMin;
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
                context.loc.recipientsCharCounter(_securityQuestion.length),
                style: TextStyle(
                  fontSize: 12,
                  color: _securityQuestion.length < 10
                      ? context.appColors.error
                      : context.appColors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsFieldSecurityAnswer,
            hintText: context.loc.recipientsFieldSecurityAnswerHint,
            focusNode: _securityAnswerFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _securityAnswer = value;
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
          ),
        ],
      ),
    );
  }
}
