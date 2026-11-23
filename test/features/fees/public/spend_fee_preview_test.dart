import 'package:spend/fee_preview.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/testing.dart';

void main() {
  test('only the original review slot retains its spend authority', () {
    final previews = SpendFeePreview();
    final prepared = SpendFixtures.preparedBitcoin(
      unsignedPsbt: 'fixture',
      fee: Sats.fromInt(300),
      txSize: 150,
    );
    const rate = RelativeFee(500);
    final slot = previews.project(
      (prepared: prepared, fee: prepared.fee),
      address: 'first',
      fee: rate,
    );

    expect(
      previews.prepared(slot, address: 'first', fee: rate),
      same(prepared),
    );
    expect(previews.prepared(slot, address: 'second', fee: rate), isNull);
    expect(
      previews.prepared(slot, address: 'first', fee: const RelativeFee(750)),
      isNull,
    );
    expect(
      previews.prepared(
        const BitcoinFeePreviewSlot(
          feeSat: 300,
          unsignedPsbt: 'fixture',
          txSize: 150,
        ),
        address: 'first',
        fee: rate,
      ),
      isNull,
    );
  });
}
