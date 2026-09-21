import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipient_form_submission.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class SepaEurForm extends StatefulWidget {
  const SepaEurForm({super.key, this.recipient, this.hookError});

  final RecipientViewModel? recipient;
  final String? hookError;

  @override
  SepaEurFormState createState() => SepaEurFormState();
}

class SepaEurFormState extends State<SepaEurForm> {
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
  late bool _onlyOwnerPermitted;

  @override
  void initState() {
    super.initState();
    _onlyOwnerPermitted = context
        .read<RecipientsBloc>()
        .state
        .onlyOwnerRecipients;
    final recipient = widget.recipient;
    _iban = recipient?.iban ?? '';
    _firstname = recipient?.firstname ?? '';
    _lastname = recipient?.lastname ?? '';
    _corporateName = recipient?.corporateName ?? '';
    _label = recipient?.label ?? '';
    _isCorporate = recipient?.isCorporate ?? false;
    _isMyAccount = recipient?.isOwner ?? _onlyOwnerPermitted;
  }

  @override
  void dispose() {
    _ibanFocusNode.dispose();
    _firstnameFocusNode.dispose();
    _lastnameFocusNode.dispose();
    _corporateNameFocusNode.dispose();
    _labelFocusNode.dispose();
    super.dispose();
  }

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
            initialValue: _iban,
            labelText: context.loc.recipientsFieldIban,
            errorText: recipientUpdateFieldError(context, 'iban'),
            hintText: context.loc.recipientsFieldIbanHint,
            focusNode: _ibanFocusNode,
            autofocus: true,
            textInputAction: .next,
            onFieldSubmitted: (_) {
              if (_isCorporate) {
                _corporateNameFocusNode.requestFocus();
              } else {
                _firstnameFocusNode.requestFocus();
              }
            },
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _iban = value;
              });
            },
          ),
          const Gap(16.0),
          CheckboxListTile(
            title: Text(context.loc.recipientsFieldCorporateAccount),
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
            controlAffinity: .leading,
          ),
          const Gap(12.0),
          if (!_isCorporate) ...[
            BBTextFormField(
              key: const ValueKey('sepa-firstname'),
              initialValue: _firstname,
              labelText: context.loc.recipientsFieldFirstName,
              errorText: recipientUpdateFieldError(context, 'firstname'),
              hintText: context.loc.recipientsFieldFirstNameHint,
              focusNode: _firstnameFocusNode,
              textInputAction: .next,
              onFieldSubmitted: (_) => _lastnameFocusNode.requestFocus(),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.loc.recipientsValidationFieldRequired
                  : null,
              onChanged: (value) {
                setState(() {
                  _firstname = value;
                });
              },
            ),
            const Gap(12.0),
            BBTextFormField(
              key: const ValueKey('sepa-lastname'),
              initialValue: _lastname,
              labelText: context.loc.recipientsFieldLastName,
              errorText: recipientUpdateFieldError(context, 'lastname'),
              hintText: context.loc.recipientsFieldLastNameHint,
              focusNode: _lastnameFocusNode,
              textInputAction: .next,
              onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.loc.recipientsValidationFieldRequired
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
              key: const ValueKey('sepa-corporate-name'),
              initialValue: _corporateName,
              labelText: context.loc.recipientsFieldCorporateName,
              errorText: recipientUpdateFieldError(context, 'corporateName'),
              hintText: context.loc.recipientsFieldCorporateNameHint,
              focusNode: _corporateNameFocusNode,
              textInputAction: .next,
              onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.loc.recipientsValidationFieldRequired
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
            key: const ValueKey('sepa-label'),
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
}
