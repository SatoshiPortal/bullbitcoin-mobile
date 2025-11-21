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
  late TextEditingController _controller;
  String? _errorText;

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

  bool _validatePort(String value) {
    final port = int.tryParse(value);
    if (port == null) {
      setState(() => _errorText = 'Please enter a valid number');
      return false;
    }
    if (port < 1 || port > 65535) {
      setState(() => _errorText = 'Port must be between 1 and 65535');
      return false;
    }
    setState(() => _errorText = null);
    return true;
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
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Port Number',
              hintText: '9050',
              errorText: _errorText,
              border: const OutlineInputBorder(),
              helperText: 'Default Orbot port: 9050',
            ),
            onChanged: _validatePort,
            autofocus: true,
          ),
          const Gap(24),
          BBButton.big(
            label: 'Save',
            onPressed: () {
              final value = _controller.text;
              if (_validatePort(value)) {
                Navigator.of(context).pop(int.parse(value));
              }
            },
            bgColor: context.colour.primary,
            textColor: context.colour.onPrimary,
          ),
        ],
      ),
    );
  }
}
