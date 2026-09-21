import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipient_form_submission.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

String? validateSinpeMovilPhone(String? value, AppLocalizations loc) {
  if (value == null || value.trim().isEmpty) {
    return loc.recipientsValidationFieldRequired;
  }

  final raw = value.trim().replaceAll(RegExp(r'\s'), '');

  if (raw.contains('+') || raw.startsWith('506')) {
    return loc.recipientsValidationSinpePhoneCountryCode;
  }
  if (RegExp(r'[^0-9]').hasMatch(raw)) {
    return loc.recipientsValidationSinpePhoneInvalidChars;
  }
  if (raw.length < 8) {
    return loc.recipientsValidationSinpePhoneTooShort;
  }
  if (raw.length > 8) {
    return loc.recipientsValidationSinpePhoneCountryCode;
  }

  return null;
}

class SinpeMovilCrcForm extends StatefulWidget {
  const SinpeMovilCrcForm({super.key, this.recipient, this.hookError});

  final RecipientViewModel? recipient;
  final String? hookError;

  @override
  SinpeMovilCrcFormState createState() => SinpeMovilCrcFormState();
}

class SinpeMovilCrcFormState extends State<SinpeMovilCrcForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _phoneNumberFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _phoneNumber = '';
  String _initialPhoneNumber = '';
  final TextEditingController _ownerNameController = TextEditingController();
  String _label = '';
  late StreamSubscription<RecipientsState> _stateSubscription;

  bool get _isPhoneValid =>
      validateSinpeMovilPhone(_phoneNumber, context.loc) == null;

  bool get _isOwnerValidated =>
      _ownerNameController.text.trim().isNotEmpty ||
      (widget.recipient != null && _phoneNumber == _initialPhoneNumber);

  @override
  void initState() {
    super.initState();
    final recipient = widget.recipient;
    _phoneNumber = recipient?.phoneNumber ?? '';
    _initialPhoneNumber = _phoneNumber;
    _ownerNameController.text = recipient?.ownerName ?? '';
    _label = recipient?.label ?? '';
    _stateSubscription = context.read<RecipientsBloc>().stream.listen((state) {
      if (state.sinpeOwnerName.isNotEmpty &&
          _ownerNameController.text != state.sinpeOwnerName) {
        setState(() {
          _ownerNameController.text = state.sinpeOwnerName;
        });
      }
    });
  }

  @override
  void dispose() {
    _phoneNumberFocusNode.dispose();
    _labelFocusNode.dispose();
    _ownerNameController.dispose();
    _stateSubscription.cancel();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = SinpeMovilCrcFormDataModel(
        phoneNumber: _phoneNumber.trim(),
        ownerName: _ownerNameController.text,
        label: _label.isEmpty ? null : _label,
      );

      submitRecipientForm(context, formData, recipient: widget.recipient);
    }
  }

  String? _validatePhoneNumberInput(String? value) {
    return validateSinpeMovilPhone(value, context.loc);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          BBTextFormField(
            initialValue: _phoneNumber,
            labelText: context.loc.recipientsFieldPhoneNumber,
            errorText: recipientUpdateFieldError(context, 'phoneNumber'),
            hintText: context.loc.recipientsFieldSinpePhoneNumberHint,
            focusNode: _phoneNumberFocusNode,
            autofocus: true,
            prefixText: '+506',
            textInputAction: .next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator: _validatePhoneNumberInput,
            onChanged: (value) {
              setState(() {
                _phoneNumber = value;
              });
              _ownerNameController.text = '';

              if (_isPhoneValid) {
                context.read<RecipientsBloc>().add(
                  RecipientsEvent.sinpeChecked(value.trim()),
                );
              }
            },
          ),
          const Gap(8.0),
          BlocSelector<RecipientsBloc, RecipientsState, bool>(
            selector: (state) => state.isCheckingSinpe,
            builder: (context, isChecking) {
              return BBTextFormField(
                labelText: context.loc.recipientsFieldOwnerName,
                errorText: recipientUpdateFieldError(context, 'ownerName'),
                hintText: context.loc.recipientsFieldOwnerNameSinpeHint,
                controller: _ownerNameController,
                disabled: true,
                suffix: _ownerNameController.text.isNotEmpty
                    ? Icon(Icons.check_circle, color: context.appColors.primary)
                    : isChecking
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.appColors.primary,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.check_circle_outline,
                        color: context.appColors.outline,
                      ),
                validator: (v) {
                  if ((v == null || v.trim().isEmpty) && !_isOwnerValidated) {
                    return context.loc.recipientsValidationSinpeOwner;
                  }
                  return null;
                },
              );
            },
          ),
          const Gap(12.0),
          BBTextFormField(
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
          const Gap(24.0),
          RecipientFormContinueButton(
            onPressed: _submitForm,
            hookError: widget.hookError,
            formDisabled: !_isPhoneValid || !_isOwnerValidated,
            isEditing: widget.recipient != null,
          ),
        ],
      ),
    );
  }
}
