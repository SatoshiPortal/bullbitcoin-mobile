import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/swap_server_setting_repository.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';

/// Edits the Boltz backend the swap engine talks to. Stored outside the
/// database; the engine reads it once at launch, so changes apply on the
/// next app start (the helper copy says so).
Future<void> showSwapServerDialog(BuildContext context) async {
  final repository = locator<SwapServerSettingRepository>();
  final current = await repository.fetch();
  final isTestnet =
      (await locator<SettingsRepository>().fetch()).environment.isTestnet;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (_) => _SwapServerDialog(
      repository: repository,
      initialUrl: current == SwapServerSettingRepository.defaultUrl
          ? ''
          : current,
      isTestnet: isTestnet,
    ),
  );
}

class _SwapServerDialog extends StatefulWidget {
  final SwapServerSettingRepository repository;
  final String initialUrl;
  final bool isTestnet;

  const _SwapServerDialog({
    required this.repository,
    required this.initialUrl,
    required this.isTestnet,
  });

  @override
  State<_SwapServerDialog> createState() => _SwapServerDialogState();
}

class _SwapServerDialogState extends State<_SwapServerDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    await widget.repository.reset();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final input = _controller.text.trim();
    // Plaintext servers are a testnet-only dev affordance.
    if (!SwapServerSettingRepository.isValid(_controller.text) ||
        (!widget.isTestnet && SwapServerSettingRepository.isPlaintext(input))) {
      setState(() => _errorText = context.loc.swapServerInvalid);
      return;
    }
    await widget.repository.save(_controller.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.loc.swapServerTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.loc.swapServerSubtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: SwapServerSettingRepository.defaultUrl,
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _reset, child: Text(context.loc.swapServerReset)),
        TextButton(
          onPressed: _save,
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
