import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts a finalized PSBT after its UTXO metadata is removed', () async {
    const finalized =
        'cHNidP8BAIkCAAAAAaWqMHcygsAiO4oBjpGSIPmYdwL2TRrCaGIazFlx9nzHAAAAAAD9'
        '////AlAxAQAAAAAAIlEg1zrPZme3hQ5uAOIbtFJaLF4tiJVqPSw1sLwG9LDfAbxoUQAA'
        'AAAAACJRICvvoUQx1MtxiJ6h33p+qi8di5EH5gsBVk4V2r5cDf0yAAAAAAABASughgEA'
        'AAAAACJRIDuCsrKpGFMV2m+A2l8G0EQNil4UV/qTOHwtkZyG7IeGAQhCAUBQGEy2i7Gu'
        'AA3sZudHK1rR6K52NHRoVkiCiqYusKp0PZIQ03fiwKiRWXEiXBCmdt3gLoDwBTylRj1B'
        'PEDYXE27AAEFILEKyX9nbPHzzNrLC3gXEoK76UqU3xQyAXANxZvMFfNoAAEFIDBYZ59tY'
        'Lh++SHZiiqaHx4Hedrie+29HNsvFHoHg1rJAA==';
    final expected = await BitcoinTx.fromPsbt(finalized);
    final stripped = Psbt.fromBase64(finalized)
      ..input.removeInputKeys(0, [
        PsbtInputTypes.nonWitnessUTXO,
        PsbtInputTypes.witnessUTXO,
      ]);

    final actual = await BitcoinTx.fromPsbt(stripped.toBase64());

    expect(actual.txid, expected.txid);
    expect(actual.inputs, expected.inputs);
    expect(actual.outputs, expected.outputs);
    expect(actual.vsize, expected.vsize);
    expect(actual.size, expected.size);
  });
}
