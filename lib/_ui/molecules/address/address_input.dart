import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_ui/atoms/bb_form_field.dart';
import 'package:flutter/material.dart';

class AddressInput extends StatelessWidget {
  const AddressInput({
    super.key,
    required this.addressController,
    this.label = 'Address',
    this.disabled = false,
    this.decoration,
    this.errorMsg = '',
    this.showPaste = true,
    this.showScan = true,
  });

  final TextEditingController addressController;
  final String label;
  final bool disabled;
  final InputDecoration? decoration;
  final String errorMsg;

  final bool showPaste;
  final bool showScan;

  Future<void> _onPaste() async {
    final String? text = await BBClipboard.paste();

    addressController.text = text ?? '';
  }

  Future<void> _onScan() async {}

  @override
  Widget build(BuildContext context) {
    return BBFormField(
      label: label,
      editingController: addressController,
      disabled: disabled,
      errorMsg: errorMsg,
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPaste)
            IconButton(
              icon: const Icon(Icons.paste),
              onPressed: _onPaste,
            ),
          if (showScan)
            IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: _onScan,
            ),
        ],
      ),
    );
  }
}
