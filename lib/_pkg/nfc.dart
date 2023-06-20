import 'package:bb_mobile/_pkg/error.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NFCPicker {
  Future<Err?> startSession(Function(String) onDiscovered) async {
    try {
      await NfcManager.instance.startSession(
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
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Err? stopSession() {
    try {
      NfcManager.instance.stopSession();
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }
}
