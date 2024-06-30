import 'package:bb_arch/_ui/atoms/bb_form_field.dart';
import 'package:flutter/material.dart';

class AddressInput extends StatelessWidget {
  const AddressInput({
    super.key,
    required this.addressController,
    this.label = 'Address',
    this.disabled = false,
    this.decoration,
    this.errorMsg = '',
  });

  final TextEditingController addressController;
  final String label;
  final bool disabled;
  final InputDecoration? decoration;
  final String errorMsg;

  @override
  Widget build(BuildContext context) {
    return BBFormField(
      label: label,
      editingController: addressController,
      disabled: disabled,
      errorMsg: errorMsg,
    );
  }
}
