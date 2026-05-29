import 'dart:async';
import 'dart:io' show Platform;

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/nfc_payload_parser.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/nfc_scanner_widget.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;

class NfcBottomSheet {
  static Future<void> showReadNfc({
    required BuildContext context,
    required String title,
    required FutureOr<void> Function(String payload) onDataReceived,
  }) async {
    var didReadRecords = false;
    final payload = await _runWithNfcSession<String?>(
      context: context,
      title: title,
      action: (_) async {
        final payload = await _readNfcPayload();
        didReadRecords = true;
        return payload;
      },
    );

    if (payload == null || payload.isEmpty) {
      if (didReadRecords) _showInvalidDataError(context);
      return;
    }

    await onDataReceived(payload);
  }

  static Future<void> showWriteNfc({
    required BuildContext context,
    required String title,
    required String data,
    required FutureOr<void> Function() onSuccess,
  }) async {
    final didWrite = await _runWithNfcSession<bool>(
      context: context,
      title: title,
      action: (_) => _writeNfcData(data),
    );

    if (didWrite == true) {
      await onSuccess();
    }
  }

  static Future<T?> _runWithNfcSession<T>({
    required BuildContext context,
    required String title,
    required Future<T?> Function(NFCTag tag) action,
  }) async {
    final availability = await _nfcAvailability(context);
    if (availability == null) return null;

    if (availability != NFCAvailability.available) {
      _showAvailabilityError(context, availability);
      return null;
    }

    if (!context.mounted) return null;

    if (Platform.isIOS) {
      try {
        // Coldcard uses NFC-V / ISO-15693.
        final tag = await FlutterNfcKit.poll(
          iosAlertMessage: title,
          readIso15693: true,
          readIso18092: false,
        );
        return await action(tag);
      } catch (e) {
        _handleNfcError(context, e);
        return null;
      }
    }

    T? result;
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
                  child: NfcScannerWidget(
                    onError: (error) => _handleNfcError(sheetContext, error),
                    onScanned: (tag) async {
                      try {
                        result = await action(tag);
                      } catch (e) {
                        _handleNfcError(sheetContext, e);
                      }
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

    return result;
  }

  static Future<NFCAvailability?> _nfcAvailability(BuildContext context) async {
    try {
      return await FlutterNfcKit.nfcAvailability;
    } catch (e) {
      _handleNfcError(context, e);
      return null;
    }
  }

  static Future<String?> _readNfcPayload() async {
    try {
      final records = await FlutterNfcKit.readNDEFRecords();
      return payloadFromNdefRecords(records);
    } finally {
      await _finishNfcSession();
    }
  }

  static Future<bool> _writeNfcData(String data) async {
    try {
      await FlutterNfcKit.writeNDEFRecords([
        ndef.TextRecord(
          text: data,
          language: 'en',
          encoding: ndef.TextEncoding.UTF8,
        ),
      ]);
      return true;
    } finally {
      await _finishNfcSession();
    }
  }

  static Future<void> _finishNfcSession() async {
    try {
      await FlutterNfcKit.finish();
    } catch (e) {
      log.warning('Failed to finish NFC session', error: e);
    }
  }

  static void _showAvailabilityError(
    BuildContext context,
    NFCAvailability availability,
  ) {
    if (!context.mounted) return;

    final message = switch (availability) {
      NFCAvailability.disabled => context.loc.nfcDisabled,
      NFCAvailability.not_supported => context.loc.nfcNotAvailable,
      NFCAvailability.available => context.loc.nfcNotAvailable,
    };
    SnackBarUtils.showSnackBar(context, message);
  }

  static void _handleNfcError(BuildContext context, Object error) {
    log.warning('NFC operation failed', error: error);
    if (!context.mounted || _isUserCancelled(error)) return;
    SnackBarUtils.showSnackBar(context, context.loc.nfcError(error.toString()));
  }

  static void _showInvalidDataError(BuildContext context) {
    log.warning('NFC tag contained no supported payload');
    if (!context.mounted) return;
    SnackBarUtils.showSnackBar(context, context.loc.nfcInvalidData);
  }

  static bool _isUserCancelled(Object error) =>
      error.toString().contains('Session invalidated by user');
}
