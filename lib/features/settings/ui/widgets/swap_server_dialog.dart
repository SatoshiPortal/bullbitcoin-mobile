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
  if (!context.mounted) return;

  final controller = TextEditingController(
    text: current == SwapServerSettingRepository.defaultUrl ? '' : current,
  );

  String? errorText;
  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(dialogContext.loc.swapServerTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogContext.loc.swapServerSubtitle,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: SwapServerSettingRepository.defaultUrl,
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await repository.reset();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Text(dialogContext.loc.swapServerReset),
            ),
            TextButton(
              onPressed: () async {
                if (!SwapServerSettingRepository.isValid(controller.text)) {
                  setState(
                    () => errorText = dialogContext.loc.swapServerInvalid,
                  );
                  return;
                }
                await repository.save(controller.text);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Text(
                MaterialLocalizations.of(dialogContext).okButtonLabel,
              ),
            ),
          ],
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}
