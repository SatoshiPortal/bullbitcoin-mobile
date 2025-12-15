import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
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
      backgroundColor: context.appColors.surface,
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

  String? _validatePort(String? value, BuildContext context) {
    if (value == null || value.isEmpty) {
      return context.loc.torSettingsPortValidationEmpty;
    }
    final port = int.tryParse(value);
    if (port == null) {
      return context.loc.torSettingsPortValidationInvalid;
    }
    if (port < 1 || port > 65535) {
      return context.loc.torSettingsPortValidationRange;
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
          mainAxisSize: .min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: BBText(
                    context.loc.torSettingsProxyPort,
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
              decoration: InputDecoration(
                labelText: context.loc.torSettingsPortNumber,
                hintText: context.loc.torSettingsPortHint,
                border: const OutlineInputBorder(),
                helperText: context.loc.torSettingsPortHelper,
              ),
              validator: (value) => _validatePort(value, context),
              onFieldSubmitted: (_) => _submit(),
              autofocus: true,
            ),
            const Gap(24),
            BBButton.big(
              label: context.loc.torSettingsSaveButton,
              onPressed: _submit,
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
