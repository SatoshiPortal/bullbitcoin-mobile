import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;

abstract interface class NfcKitDatasource {
  Future<NFCAvailability> availability();

  Future<NFCTag> poll({
    required Duration timeout,
    required String iosAlertMessage,
  });

  Future<List<ndef.NDEFRecord>> readNdefRecords();

  Future<void> writeTextRecord(String data);

  Future<void> finish({String? iosAlertMessage, String? iosErrorMessage});

  Future<void> setIosAlertMessage(String message);

  Future<void> iosRestartPolling();
}

final class FlutterNfcKitDatasource implements NfcKitDatasource {
  const FlutterNfcKitDatasource();

  @override
  Future<NFCAvailability> availability() => FlutterNfcKit.nfcAvailability;

  @override
  Future<NFCTag> poll({
    required Duration timeout,
    required String iosAlertMessage,
  }) => FlutterNfcKit.poll(
    timeout: timeout,
    iosAlertMessage: iosAlertMessage,
    readIso15693: true,
    readIso18092: false,
  );

  @override
  Future<List<ndef.NDEFRecord>> readNdefRecords() =>
      FlutterNfcKit.readNDEFRecords();

  @override
  Future<void> writeTextRecord(String data) => FlutterNfcKit.writeNDEFRecords([
    ndef.TextRecord(
      text: data,
      language: 'en',
      encoding: ndef.TextEncoding.UTF8,
    ),
  ]);

  @override
  Future<void> finish({String? iosAlertMessage, String? iosErrorMessage}) =>
      FlutterNfcKit.finish(
        iosAlertMessage: iosAlertMessage,
        iosErrorMessage: iosErrorMessage,
      );

  @override
  Future<void> setIosAlertMessage(String message) =>
      FlutterNfcKit.setIosAlertMessage(message);

  @override
  Future<void> iosRestartPolling() => FlutterNfcKit.iosRestartPolling();
}
