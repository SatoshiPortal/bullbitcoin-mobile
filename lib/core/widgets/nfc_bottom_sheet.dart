import 'dart:async';

import 'package:bb_mobile/core/nfc/domain/nfc_failure.dart';
import 'package:bb_mobile/core/nfc/domain/nfc_session.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/nfc/nfc_scan_flow.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';

class NfcBottomSheet {
  static Future<void> showReadNfc({
    required BuildContext context,
    required String title,
    required FutureOr<void> Function(String payload) onDataReceived,
  }) async {
    final tagLostMessage = context.loc.nfcConnectionLost;

    final payload = await _showSheet(
      context: context,
      title: title,
      run: (session) => session.readPayload(
        iosAlertMessage: title,
        iosTagLostMessage: tagLostMessage,
      ),
    );

    if (payload == null) return;

    await onDataReceived(payload);
  }

  static Future<void> showWriteNfc({
    required BuildContext context,
    required String title,
    required String data,
    required FutureOr<void> Function() onSuccess,
  }) async {
    final writeFailedMessage = context.loc.nfcWriteFailed;

    final written = await _showSheet(
      context: context,
      title: title,
      run: (session) async {
        final result = await session.writeText(
          data: data,
          iosAlertMessage: title,
          iosErrorMessage: writeFailedMessage,
        );
        return result.map((_) => data);
      },
    );

    if (written == null) return;

    await onSuccess();
  }

  static Future<String?> _showSheet({
    required BuildContext context,
    required String title,
    required Future<Result<String, NfcFailure>> Function(NfcSession session)
    run,
  }) async {
    final session = locator<NfcSession>();
    String? payload;

    await BlurredBottomSheet.show<void>(
      context: context,
      isDismissible: true,
      child: Builder(
        builder: (sheetContext) => SafeArea(
          child: Container(
            height: 450,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: sheetContext.appColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Column(
              children: [
                BBText(
                  title,
                  style: sheetContext.font.headlineSmall,
                  color: sheetContext.appColors.text,
                  textAlign: TextAlign.center,
                ),
                Expanded(
                  child: NfcScanFlow(
                    session: session,
                    run: run,
                    onPayload: (value) {
                      payload = value;
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                    onCancelled: () {
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return payload;
  }
}
