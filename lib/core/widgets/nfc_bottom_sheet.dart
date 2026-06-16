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

enum _NfcOperation { read, write }

class NfcBottomSheet {
  static const _iosReadAttempts = 3;

  static Future<void> showReadNfc({
    required BuildContext context,
    required String title,
    required FutureOr<void> Function(String payload) onDataReceived,
  }) async {
    var didReadRecords = false;
    final connectionLostMessage = context.loc.nfcConnectionLost;
    final payload = await _runWithNfcSession<String?>(
      context: context,
      title: title,
      operation: _NfcOperation.read,
      action: (_) async {
        final payload = Platform.isIOS
            ? await _readNfcPayloadWithIosRetry(
                connectionLostMessage: connectionLostMessage,
              )
            : await _readNfcPayload();
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
    final writeFailedMessage = context.loc.nfcWriteFailed;
    final didWrite = await _runWithNfcSession<bool>(
      context: context,
      title: title,
      operation: _NfcOperation.write,
      action: (_) => _writeNfcData(data, iosErrorMessage: writeFailedMessage),
    );

    if (didWrite == true) {
      await onSuccess();
    }
  }

  static Future<T?> _runWithNfcSession<T>({
    required BuildContext context,
    required String title,
    required _NfcOperation operation,
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
      final NFCTag tag;
      try {
        // Coldcard uses NFC-V / ISO-15693.
        tag = await FlutterNfcKit.poll(
          iosAlertMessage: title,
          readIso15693: true,
          readIso18092: false,
        );
      } catch (e) {
        await _finishNfcSession();
        _handleNfcError(context, e);
        return null;
      }

      try {
        return await action(tag);
      } catch (e) {
        _handleNfcError(context, e, operation: operation);
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
                      var didCompleteAction = false;
                      try {
                        result = await action(tag);
                        didCompleteAction = true;
                      } catch (e) {
                        _handleNfcError(sheetContext, e, operation: operation);
                      }
                      if (didCompleteAction && sheetContext.mounted) {
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

  static Future<String?> _readNfcPayloadWithIosRetry({
    required String connectionLostMessage,
  }) async {
    String? iosErrorMessage;
    try {
      for (var attempt = 1; attempt <= _iosReadAttempts; attempt++) {
        try {
          final records = await FlutterNfcKit.readNDEFRecords();
          return payloadFromNdefRecords(records);
        } catch (e) {
          if (_isUserCancelled(e)) rethrow;

          final isReadInterrupted = _isNfcReadInterrupted(e);
          if (!isReadInterrupted || attempt == _iosReadAttempts) {
            if (isReadInterrupted) {
              iosErrorMessage = connectionLostMessage;
            }
            rethrow;
          }

          log.warning('NFC read interrupted; restarting polling', error: e);
          iosErrorMessage = connectionLostMessage;
          await _setIosAlertMessage(connectionLostMessage);
          await FlutterNfcKit.iosRestartPolling();
          iosErrorMessage = null;
        }
      }

      return null;
    } finally {
      await _finishNfcSession(iosErrorMessage: iosErrorMessage);
    }
  }

  static Future<bool> _writeNfcData(
    String data, {
    String? iosErrorMessage,
  }) async {
    try {
      await FlutterNfcKit.writeNDEFRecords([
        ndef.TextRecord(
          text: data,
          language: 'en',
          encoding: ndef.TextEncoding.UTF8,
        ),
      ]);
      await _finishNfcSession();
      return true;
    } catch (e) {
      await _finishNfcSession(
        iosErrorMessage: _isUserCancelled(e) ? null : iosErrorMessage,
      );
      rethrow;
    }
  }

  static Future<void> _finishNfcSession({String? iosErrorMessage}) async {
    try {
      await FlutterNfcKit.finish(iosErrorMessage: iosErrorMessage);
    } catch (e) {
      log.warning('Failed to finish NFC session', error: e);
    }
  }

  static Future<void> _setIosAlertMessage(String message) async {
    try {
      await FlutterNfcKit.setIosAlertMessage(message);
    } catch (e) {
      log.warning('Failed to update iOS NFC alert message', error: e);
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

  static void _handleNfcError(
    BuildContext context,
    Object error, {
    _NfcOperation? operation,
  }) {
    log.warning('NFC operation failed', error: error);
    if (!context.mounted || _isUserCancelled(error)) return;

    final message = operation == _NfcOperation.write
        ? context.loc.nfcWriteFailed
        : _isNfcReadInterrupted(error)
        ? context.loc.nfcConnectionLost
        : context.loc.nfcError(error.toString());
    SnackBarUtils.showSnackBar(context, message);
  }

  static void _showInvalidDataError(BuildContext context) {
    log.warning('NFC tag contained no supported payload');
    if (!context.mounted) return;
    SnackBarUtils.showSnackBar(context, context.loc.nfcInvalidData);
  }

  static bool _isUserCancelled(Object error) =>
      error.toString().contains('Session invalidated by user');

  static bool _isNfcReadInterrupted(Object error) {
    final message = error.toString();
    return message.contains('Tag connection lost') ||
        message.contains('Read NDEF error');
  }
}
