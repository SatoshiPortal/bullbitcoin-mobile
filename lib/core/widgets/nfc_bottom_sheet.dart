import 'dart:io' show Platform;

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
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
    required Future<void> Function(String payload) onDataReceived,
  }) async {
    await _showNfcBottomSheet(
      context: context,
      title: title,
      onNfcAction: (tag) => _handleNfcRead(tag, context, onDataReceived),
    );
  }

  static Future<void> showWriteNfc({
    required BuildContext context,
    required String title,
    required String data,
    required VoidCallback onSuccess,
  }) async {
    await _showNfcBottomSheet(
      context: context,
      title: title,
      onNfcAction: (tag) => _writeNfcData(context, data, onSuccess),
    );
  }

  static Future<void> _showNfcBottomSheet({
    required BuildContext context,
    required String title,
    required Future<void> Function(NFCTag tag) onNfcAction,
  }) async {
    final isAvailable = await FlutterNfcKit.nfcAvailability;
    if (isAvailable != NFCAvailability.available) {
      if (context.mounted) {
        final message = switch (isAvailable) {
          NFCAvailability.disabled => 'NFC is disabled. Please enable NFC in your device settings',
          NFCAvailability.not_supported => 'NFC is not supported on this device',
          _ => 'NFC is not available on this device',
        };
        SnackBarUtils.showSnackBar(context, message);
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    if (Platform.isIOS) {
      try {
        final tag = await FlutterNfcKit.poll(iosAlertMessage: title);
        if (context.mounted) {
          await onNfcAction(tag);
        }
      } catch (e) {
        log.warning('NFC operation failed', error: e);
        if (context.mounted &&
            !e.toString().contains('Session invalidated by user')) {
          SnackBarUtils.showSnackBar(context, 'NFC error: $e');
        }
      }
      return;
    }

    await BlurredBottomSheet.show(
      context: context,
      isDismissible: true,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.colour.onPrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          height: 450,
          child: Column(
            children: [
              BBText(
                title,
                style: context.font.headlineSmall,
                textAlign: TextAlign.center,
              ),
              Expanded(
                child: NfcScannerWidget(
                  onScanned: (NFCTag tag) async {
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    await onNfcAction(tag);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _handleNfcRead(
    NFCTag tag,
    BuildContext context,
    Future<void> Function(String payload) onDataReceived,
  ) async {
    try {
      final ndefRecords = await FlutterNfcKit.readNDEFRecords();

      if (ndefRecords.isEmpty) return;

      final lastRecord = ndefRecords.last;

      String payload = '';
      if (lastRecord is ndef.ExternalRecord) {
        payload =
            lastRecord.payload
                ?.map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                .join('') ??
            '';
      } else if (lastRecord is ndef.TextRecord) {
        payload = lastRecord.text ?? '';
      }

      if (payload.isEmpty) return;

      await onDataReceived(payload);
    } catch (e) {
      log.warning('Failed reading/parsing NDEF', error: e);
      if (context.mounted &&
          !e.toString().contains('Session invalidated by user')) {
        SnackBarUtils.showSnackBar(context, 'NFC error: $e');
      }
    } finally {
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
    }
  }

  static Future<void> _writeNfcData(
    BuildContext context,
    String data,
    VoidCallback onSuccess,
  ) async {
    try {
      await FlutterNfcKit.writeNDEFRecords([
        ndef.TextRecord(
          text: data,
          language: 'en',
          encoding: ndef.TextEncoding.UTF8,
        ),
      ]);

      await FlutterNfcKit.finish();
      onSuccess();
    } catch (e) {
      log.warning('Failed to send data via NFC: $e');
      if (context.mounted &&
          !e.toString().contains('Session invalidated by user')) {
        SnackBarUtils.showSnackBar(context, 'NFC error: $e');
      }
    } finally {
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
    }
  }
}
