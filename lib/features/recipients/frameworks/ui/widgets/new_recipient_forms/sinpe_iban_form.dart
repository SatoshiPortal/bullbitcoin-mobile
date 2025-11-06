import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SinpeIbanForm extends StatefulWidget {
  final RecipientType? recipientType;
  const SinpeIbanForm({super.key, this.recipientType});

  @override
  _SinpeIbanFormState createState() => _SinpeIbanFormState();
}

class _SinpeIbanFormState extends State<SinpeIbanForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _ibanFocusNode = FocusNode();
  final FocusNode _ownerNameFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _iban = '';
  String _ownerName = '';
  String _label = '';

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      // Determine the correct type based on context
      final type = widget.recipientType ?? RecipientType.sinpeIbanCrc;

      final RecipientFormDataModel formData;
      if (type == RecipientType.sinpeIbanUsd) {
        formData = SinpeIbanUsdFormDataModel(
          iban: _iban,
          ownerName: _ownerName,
          label: _label.isEmpty ? null : _label,
        );
      } else {
        formData = SinpeIbanCrcFormDataModel(
          iban: _iban,
          ownerName: _ownerName,
          label: _label.isEmpty ? null : _label,
        );
      }

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
            labelText: 'IBAN',
            hintText: 'Enter IBAN',
            focusNode: _ibanFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _ownerNameFocusNode.requestFocus(),
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? "This field can't be empty"
                        : null,
            onChanged: (value) {
              setState(() {
                _iban = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: 'Owner Name',
            hintText: 'Enter owner name',
            focusNode: _ownerNameFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? "This field can't be empty"
                        : null,
            onChanged: (value) {
              setState(() {
                _ownerName = value;
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
          const Gap(24.0),
          RecipientFormContinueButton(onPressed: _submitForm),
        ],
      ),
    );
  }
}
