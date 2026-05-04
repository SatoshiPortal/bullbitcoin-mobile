import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PosPairingCodeInput extends StatelessWidget {
  const PosPairingCodeInput({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z-]')),
        LengthLimitingTextInputFormatter(9),
      ],
      decoration: const InputDecoration(
        labelText: 'Pairing code',
        hintText: 'XXXX-XXXX',
        prefixIcon: Icon(Icons.link),
      ),
    );
  }
}
