import 'package:bb_mobile/_ui/atoms/bb_form_field.dart';
import 'package:flutter/material.dart';

class BBAmountField extends StatefulWidget {
  const BBAmountField({super.key});

  @override
  State<BBAmountField> createState() => _BBAmountFieldState();
}

class _BBAmountFieldState extends State<BBAmountField> {
  TextEditingController priceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BBFormField(label: 'Amount', editingController: priceController);
  }
}
