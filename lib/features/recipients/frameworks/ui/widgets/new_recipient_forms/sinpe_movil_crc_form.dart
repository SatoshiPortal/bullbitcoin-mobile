import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SinpeMovilCrcForm extends StatefulWidget {
  const SinpeMovilCrcForm({super.key});

  @override
  SinpeMovilCrcFormState createState() => SinpeMovilCrcFormState();
}

class SinpeMovilCrcFormState extends State<SinpeMovilCrcForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _phoneNumberFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _phoneNumber = '';
  final TextEditingController _ownerNameController = TextEditingController();
  String _label = '';
  late StreamSubscription<RecipientsState> _stateSubscription;

  @override
  void initState() {
    super.initState();
    _stateSubscription = context.read<RecipientsBloc>().stream.listen((state) {
      // Update SINPE owner name when it changes in the state, which happens
      // when a check happens, resetting the owner name and after a successful
      // SINPE validation with the correct owner name.
      if (_ownerNameController.text != state.sinpeOwnerName) {
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
        phoneNumber: _phoneNumber,
        ownerName: _ownerNameController.text,
        label: _label.isEmpty ? null : _label,
      );

      context.read<RecipientsBloc>().add(RecipientsEvent.added(formData));
    }
  }

  String? _validatePhoneNumberInput(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "This field can't be empty";
    }
    if (!RegExp(r'^\d{8}$').hasMatch(value.trim())) {
      return 'Please enter a valid 8-digit phone number';
    }
    return null;
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
            labelText: 'Phone Number',
            hintText: 'Enter phone number',
            focusNode: _phoneNumberFocusNode,
            autofocus: true,
            prefixText: '+506',
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator: _validatePhoneNumberInput,
            onChanged: (value) {
              setState(() {
                _phoneNumber = value;
              });
              // Clear the owner name when phone number changes
              _ownerNameController.text = '';

              // Check SINPE if phone number is valid
              if (_validatePhoneNumberInput(value) == null) {
                context.read<RecipientsBloc>().add(
                  RecipientsEvent.sinpeChecked(value),
                );
              }
            },
          ),
          const Gap(8.0),
          // Validation status
          BlocSelector<RecipientsBloc, RecipientsState, bool>(
            selector: (state) => state.isCheckingSinpe,
            builder: (context, isChecking) {
              return BBTextFormField(
                labelText: 'Owner Name',
                hintText: 'Owner name will appear here',
                controller: _ownerNameController,
                disabled: true,
                suffix: _ownerNameController.text.isNotEmpty
                    ? const Icon(Icons.check_circle, color: Colors.green)
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
                    : const Icon(
                        Icons.check_circle_outline,
                        color: Colors.grey,
                      ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Please validate the phone number";
                  }
                  return null;
                },
              );
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
          const Gap(24.0),
          RecipientFormContinueButton(onPressed: _submitForm),
        ],
      ),
    );
  }
}
