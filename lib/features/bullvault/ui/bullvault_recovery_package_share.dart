import 'dart:convert';
import 'dart:typed_data';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> shareBullVaultRecoveryPackage(
  BuildContext context, {
  required String content,
  required String policyId,
  VoidCallback? onExported,
}) async {
  try {
    final shortId = policyId.substring(0, 8);
    final filename = 'bullvault-recovery-$shortId.json';
    final box = context.findRenderObject() as RenderBox?;
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(content)),
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: [filename],
        subject: filename,
        sharePositionOrigin: box != null && box.hasSize
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      ),
    );
    if (!context.mounted || result.status != ShareResultStatus.success) {
      return false;
    }
    onExported?.call();
    BullSnackBar.show(
      context,
      message: context.loc.bullVaultRecoveryPackageExported,
    );
    return true;
  } on Exception {
    if (context.mounted) {
      BullSnackBar.show(context, message: context.loc.oopsSomethingWentWrong);
    }
    return false;
  }
}
