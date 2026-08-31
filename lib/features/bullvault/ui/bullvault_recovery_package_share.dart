import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> shareBullVaultRecoveryPackage(
  BuildContext context, {
  required String content,
  required String policyId,
}) async {
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
  return result.status == ShareResultStatus.success;
}
