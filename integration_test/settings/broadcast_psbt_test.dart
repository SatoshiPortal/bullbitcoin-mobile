import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test PSBT Decode & Broadcast', () {
    test('Decode signed psbt and build transaction object', () async {
      const signed =
          'cHNidP8BAHEBAAAAAUW4uS2LAueJOsWcyYh8Hvo1opUYinqkpnL2Ezd9MbZNAAAAAAD+////AoRhEQAAAAAAFgAUVOo7YRktX7MfMz23P7n1pliNPmqoYQAAAAAAABYAFEp0ZQjCTSifuqOOnpqbkysfYjRh0D0lAAABAN4CAAAAAAEBnHQOg3eByo1cT1fNDVhGzZEH55z9VOBvCXFz8NuI38EBAAAAAP3///8CucMRAAAAAAAWABSQc+w57h5Yv77kyf7HkMjgRl3PlHfZlucRAAAAFgAU7/ZK9sa4XfzHq2ip6XJdThkoTeMCRzBEAiAyprjg+Yx7g0GmWoSERfbAD0gbOyRivwk7aKsBBxRwNQIgIaS3pPQfpf2v/FhzVSUtgzbHiGJ91DaXCrf3tRKBwrwBIQLNoM8+zzAss4erKXQLnyzne/3+DbaOmkBZ6TSiOUufOc89JQABAR+5wxEAAAAAABYAFJBz7DnuHli/vuTJ/seQyOBGXc+UIgID4Rq0pVgDovVsA7E0uZqPPUpy64Q+q108XeD4jvNUEM5HMEQCIDb98ZdwGAxrDYi7FdLh0h0Cli6LPbpLf8sTwqqQDxNMAiBh+EBuAYKFmu4TEo4WbFxPGUCWx2dancbZZ3Ba0HvR3gEBAwQBAAAAIgYD4Rq0pVgDovVsA7E0uZqPPUpy64Q+q108XeD4jvNUEM4YII4+eVQAAIABAACAAAAAgAAAAAAAAAAAACICA6E01O0/KuzLOzU+nFFTS1lW2AY7qz53yx+3NQjV0DjhGCCOPnlUAACAAQAAgAAAAIABAAAAAAAAAAAA';
      final psbt = bdk.PartiallySignedTransaction(psbtBase64: signed);
      final bdkTx = await psbt.extractTx();
      final txid = await bdkTx.txid();
      final feeAmount = await psbt.feeAmount();
      final outputs = await bdkTx.output();
      final List<String> outAddresses = [];
      for (final outpoint in outputs) {
        outAddresses.add(outpoint.toString());
      }
      print({txid, feeAmount, outputs});
    });
  });
}
