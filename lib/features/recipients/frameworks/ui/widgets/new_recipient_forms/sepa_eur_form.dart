import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SepaEurForm extends StatefulWidget {
  const SepaEurForm({super.key, this.hookError});

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
    if (_onlyOwnerPermitted) {
      _isMyAccount = true;
    }
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
            labelText: context.loc.recipientsFieldIban,
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
              labelText: context.loc.recipientsFieldFirstName,
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
              labelText: context.loc.recipientsFieldLastName,
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
              labelText: context.loc.recipientsFieldCorporateName,
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
