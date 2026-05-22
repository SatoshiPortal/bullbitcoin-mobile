import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class BankTransferCadForm extends StatefulWidget {
  const BankTransferCadForm({super.key, this.hookError});

  final String? hookError;

  @override
  BankTransferCadFormState createState() => BankTransferCadFormState();
}

class BankTransferCadFormState extends State<BankTransferCadForm> {
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
    _institutionNumberFocusNode.dispose();
    _transitNumberFocusNode.dispose();
    _accountNumberFocusNode.dispose();
    _nameFocusNode.dispose();
    _defaultCommentFocusNode.dispose();
    _labelFocusNode.dispose();
    super.dispose();
  }

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
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          BBTextFormField(
            labelText: context.loc.recipientsFieldInstitutionNumber,
            hintText: context.loc.recipientsFieldInstitutionNumberHint,
            focusNode: _institutionNumberFocusNode,
            autofocus: true,
            textInputAction: .next,
            onFieldSubmitted: (_) => _transitNumberFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _institutionNumber = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsFieldTransitNumber,
            hintText: context.loc.recipientsFieldTransitNumberHint,
            focusNode: _transitNumberFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _accountNumberFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _transitNumber = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsFieldAccountNumber,
            hintText: context.loc.recipientsFieldAccountNumberHint,
            focusNode: _accountNumberFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _nameFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _accountNumber = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsFieldName,
            hintText: context.loc.recipientsFieldNameHint,
            focusNode: _nameFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _defaultCommentFocusNode.requestFocus(),
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
            labelText: context.loc.recipientsFieldDefaultComment,
            hintText: context.loc.recipientsFieldDefaultCommentHint,
            focusNode: _defaultCommentFocusNode,
            textInputAction: .next,
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
