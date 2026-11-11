import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/presentation/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/presentation/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class SepaEurForm extends StatefulWidget {
  const SepaEurForm({super.key, this.hookError, this.isConfidential = false});

  final String? hookError;

  /// Confidential SEPA only pays the user's own individual account, so the
  /// corporate and ownership choices are hidden and the name is the account
  /// owner's.
  final bool isConfidential;

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
    if (_onlyOwnerPermitted || widget.isConfidential) {
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
      final ownerName = context.read<RecipientsBloc>().state.accountOwnerName;
      final formData = SepaEurFormDataModel(
        iban: _iban,
        isCorporate: _isCorporate,
        isOwner: _isMyAccount,
        firstname: _isCorporate
            ? null
            : widget.isConfidential
            ? ownerName?.firstName
            : _firstname,
        lastname: _isCorporate
            ? null
            : widget.isConfidential
            ? ownerName?.lastName
            : _lastname,
        corporateName: _isCorporate ? _corporateName : null,
        label: _label.isEmpty ? null : _label,
        isConfidential: widget.isConfidential,
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
            labelText: context.loc.recipientsFieldBankAccountIban,
            hintText: context.loc.recipientsFieldIbanHint,
            focusNode: _ibanFocusNode,
            autofocus: true,
            textInputAction: .next,
            onFieldSubmitted: (_) {
              if (widget.isConfidential) {
                _labelFocusNode.requestFocus();
              } else if (_isCorporate) {
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
          if (!widget.isConfidential)
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
          if (widget.isConfidential) ...[
            const _AccountOwnerNameField(),
            const Gap(12.0),
          ] else if (!_isCorporate) ...[
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
          if (!widget.isConfidential) ...[
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
          ],
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

class _AccountOwnerNameField extends StatefulWidget {
  const _AccountOwnerNameField();

  @override
  State<_AccountOwnerNameField> createState() => _AccountOwnerNameFieldState();
}

class _AccountOwnerNameFieldState extends State<_AccountOwnerNameField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fullName = context.select(
      (RecipientsBloc bloc) => bloc.state.accountOwnerName?.fullName ?? '',
    );
    if (_controller.text != fullName) _controller.text = fullName;

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        BBTextFormField(
          labelText: context.loc.recipientsVirtualIbanAccountOwnerName,
          controller: _controller,
          disabled: true,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? context.loc.recipientsValidationFieldRequired
              : null,
        ),
        const Gap(8.0),
        Text(
          context.loc.recipientsConfidentialSepaNameMustMatchHint,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.outline,
          ),
        ),
      ],
    );
  }
}
