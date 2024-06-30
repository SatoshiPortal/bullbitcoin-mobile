import 'package:flutter/material.dart';

class BBFormField extends StatelessWidget {
  const BBFormField(
      {super.key,
      required this.label,
      required this.editingController,
      this.keyboardType,
      this.disabled = false,
      this.centered = false,
      this.errorMsg = ''});

  final String label;
  final TextEditingController editingController;
  final TextInputType? keyboardType;
  final bool disabled;
  final bool centered;
  final String errorMsg;
  // final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final finalDecoration = errorMsg.isEmpty
        ? const InputDecoration(border: OutlineInputBorder())
        : InputDecoration(
            border: const OutlineInputBorder(),
            error: Text(
              errorMsg,
              style: TextStyle(color: Colors.red),
            ),
          );

    return Column(
        crossAxisAlignment: centered == true
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(
            height: 10,
          ),
          TextFormField(
            controller: editingController,
            keyboardType: keyboardType,
            enabled: !disabled,
            decoration: finalDecoration,
          ),
          const SizedBox(
            height: 20,
          ),
        ]);
  }
}
