import 'dart:async';
import 'dart:io' show Platform;

import 'package:bull_logger/bull_logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullShapesX,
        BullSnackBar,
        BullText,
        BullThemeX,
        BullTypographyX;

import '../generated/l10n/scanning_localizations.dart';
import 'nfc_payload_parser.dart';
import 'nfc_scanner_widget.dart';

enum _NfcOperation { read, write }

class NfcBottomSheet {
  static const _iosReadAttempts = 3;

  static Future<void> showReadNfc({
    required BuildContext context,
    required String title,
    required FutureOr<void> Function(String payload) onDataReceived,
  }) async {
    final labels = ScanningLocalizations.of(context);
    var didReadRecords = false;
    final connectionLostMessage = labels.nfcConnectionLost;
    final payload = await _runWithNfcSession<String?>(
      context: context,
      title: title,
      labels: labels,
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
      if (didReadRecords && context.mounted) {
        log.warning('NFC tag contained no supported payload');
        BullSnackBar.show(context, message: labels.nfcInvalidData);
      }
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
    final labels = ScanningLocalizations.of(context);
    final writeFailedMessage = labels.nfcWriteFailed;
    final didWrite = await _runWithNfcSession<bool>(
      context: context,
      title: title,
      labels: labels,
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
    required ScanningLocalizations labels,
    required _NfcOperation operation,
    required Future<T?> Function(NFCTag tag) action,
  }) async {
    final availability = await _nfcAvailability(context, labels);
    if (availability == null) return null;

    if (availability != NFCAvailability.available) {
      _showAvailabilityError(context, availability, labels);
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
        _handleNfcError(context, e, labels);
        return null;
      }

      try {
        return await action(tag);
      } catch (e) {
        _handleNfcError(context, e, labels, operation: operation);
        return null;
      }
    }

    T? result;
    await BullBottomSheet.show<void>(
      context: context,
      isDismissible: true,
      child: Builder(
        builder: (sheetContext) => SafeArea(
          child: Container(
            height: 450,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: sheetContext.bull.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(sheetContext.bullShapes.sheet),
              ),
            ),
            child: Column(
              children: [
                Semantics(
                  header: true,
                  child: BullText(
                    title,
                    style: sheetContext.bullType.subtitle.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                    color: sheetContext.bull.text,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: NfcScannerWidget(
                    onError: (error) =>
                        _handleNfcError(sheetContext, error, labels),
                    onScanned: (tag) async {
                      var didCompleteAction = false;
                      try {
                        result = await action(tag);
                        didCompleteAction = true;
                      } catch (e) {
                        _handleNfcError(
                          sheetContext,
                          e,
                          labels,
                          operation: operation,
                        );
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

  static Future<NFCAvailability?> _nfcAvailability(
    BuildContext context,
    ScanningLocalizations labels,
  ) async {
    try {
      return await FlutterNfcKit.nfcAvailability;
    } catch (e) {
      _handleNfcError(context, e, labels);
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

          log.warning(
            'NFC read interrupted; restarting polling',
            error: e.runtimeType,
          );
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
      log.warning('Failed to finish NFC session', error: e.runtimeType);
    }
  }

  static Future<void> _setIosAlertMessage(String message) async {
    try {
      await FlutterNfcKit.setIosAlertMessage(message);
    } catch (e) {
      log.warning(
        'Failed to update iOS NFC alert message',
        error: e.runtimeType,
      );
    }
  }

  static void _showAvailabilityError(
    BuildContext context,
    NFCAvailability availability,
    ScanningLocalizations labels,
  ) {
    if (!context.mounted) return;

    final message = switch (availability) {
      NFCAvailability.disabled => labels.nfcDisabled,
      NFCAvailability.not_supported => labels.nfcNotAvailable,
      NFCAvailability.available => labels.nfcNotAvailable,
    };
    BullSnackBar.show(context, message: message);
  }

  static void _handleNfcError(
    BuildContext context,
    Object error,
    ScanningLocalizations labels, {
    _NfcOperation? operation,
  }) {
    log.warning('NFC operation failed', error: error.runtimeType);
    if (!context.mounted || _isUserCancelled(error)) return;

    final message = operation == _NfcOperation.write
        ? labels.nfcWriteFailed
        : _isNfcReadInterrupted(error)
        ? labels.nfcConnectionLost
        : labels.nfcFailed;
    BullSnackBar.show(context, message: message);
  }

  static bool _isUserCancelled(Object error) =>
      error.toString().contains('Session invalidated by user');

  static bool _isNfcReadInterrupted(Object error) {
    final message = error.toString();
    return message.contains('Tag connection lost') ||
        message.contains('Read NDEF error');
  }
}
