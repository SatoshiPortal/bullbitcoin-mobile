import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class DeleteCustomServerDialog {
  static Future<bool?> show(
    BuildContext context,
    String serverUrl,
    bool isLastCustomServer,
  ) {
    return showDialog<bool>(
      context: context,
      builder:
          (BuildContext dialogContext) => AlertDialog(
            backgroundColor: context.colour.onPrimary,
            title: Text(context.loc.electrumDeleteServerTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLastCustomServer)
                  Text(
                    context.loc.electrumDeletePrivacyNotice,
                    style: context.font.bodyMedium,
                  ),
                Text(
                  context.loc.electrumDeleteConfirmation(serverUrl),
                  style: context.font.bodyMedium,
                ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: BBButton.small(
                      label: context.loc.electrumCancel,
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      bgColor: Colors.transparent,
                      outlined: true,
                      textStyle: context.font.headlineLarge,
                      textColor: context.colour.secondary,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: BBButton.small(
                      label: context.loc.electrumDelete,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      bgColor: context.colour.error,
                      textStyle: context.font.headlineLarge,
                      textColor: context.colour.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }
}
