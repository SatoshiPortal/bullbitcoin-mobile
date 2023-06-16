import 'package:nfc_manager/nfc_manager.dart';

class NFCPicker {
  Future startSession(Function(String) onDiscovered) {
    return NfcManager.instance.startSession(
      onDiscovered: (tag) async {
        final ndef = Ndef.from(tag);
        if (ndef != null) {
          final message = await ndef.read();
          final payload = message.records.first.payload;
          final xpub = String.fromCharCodes(payload);
          onDiscovered(xpub);
          stopSession();
        }
      },
    );
  }

  void stopSession() {
    try {
      NfcManager.instance.stopSession();
    } catch (e) {
      //
    }
  }
}
