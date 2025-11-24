import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class TorPortInputBottomSheet extends StatefulWidget {
  const TorPortInputBottomSheet({super.key, required this.currentPort});

  final int currentPort;

  static Future<int?> show(BuildContext context, int currentPort) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colour.secondaryFixed,
      useSafeArea: true,
      builder: (context) => TorPortInputBottomSheet(currentPort: currentPort),
    );
  }

  @override
  State<TorPortInputBottomSheet> createState() =>
      _TorPortInputBottomSheetState();
}

class _TorPortInputBottomSheetState extends State<TorPortInputBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPort.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validatePort(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a port number';
    }
    final port = int.tryParse(value);
    if (port == null) {
      return 'Please enter a valid number';
    }
    if (port < 1 || port > 65535) {
      return 'Port must be between 1 and 65535';
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(int.parse(_controller.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: BBText(
                    'Tor Proxy Port',
                    style: context.font.headlineMedium,
                  ),
                ),
                Positioned(
                  right: 0,
                  child: IconButton(
                    iconSize: 24,
                    icon: const Icon(Icons.close),
                    onPressed: context.pop,
                  ),
                ),
              ],
            ),
            const Gap(24),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Port Number',
                hintText: '9050',
                border: OutlineInputBorder(),
                helperText: 'Default Orbot port: 9050',
              ),
              validator: _validatePort,
              onFieldSubmitted: (_) => _submit(),
              autofocus: true,
            ),
            const Gap(24),
            BBButton.big(
              label: 'Save',
              onPressed: _submit,
              bgColor: context.colour.primary,
              textColor: context.colour.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
