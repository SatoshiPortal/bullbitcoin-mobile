import 'package:boltz_swaps/src/util.dart';
import 'package:test/test.dart';

// Deterministic fixture: invoice signed with a throwaway key whose payment
// hash is sha256 of a 32-byte 0x2a preimage (mirrors the boltz-rust vectors
// so both layers verify the same pair).
const _invoice =
    'lnbc1pnwp2uqdpswejhy6tx090hxatzd4shy6twv40hqun9d9kkzem9yp6x2um5pp5238x9'
    'nhgqvmsncufuke8256r6rg04rzg2qs4e7mrx9chaqx3463ssp5qurswpc8qurswpc8qursw'
    'pc8qurswpc8qurswpc8qurswpc8qurs9qrsgqcqzyszy8d43nzfdv30dwg94qewenply4xj'
    'em57tgrztwjhw04jcgh57jxtsqskm4a8hqydnr8ehevsx70x0c6mmpaxqyhdvz7g927jh55'
    'mvcqwgxy2s';
const _preimage =
    '2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a';

void main() {
  test('accepts the preimage that hashes to the invoice payment hash', () {
    expect(
      preimageMatchesInvoice(preimage: _preimage, invoice: _invoice),
      isTrue,
    );
  });

  test('rejects a preimage that does not hash to the payment hash', () {
    final wrong = _preimage.replaceFirst('2a', '2b');
    expect(preimageMatchesInvoice(preimage: wrong, invoice: _invoice), isFalse);
  });

  test('fails closed on garbage input', () {
    expect(
      preimageMatchesInvoice(preimage: 'not-hex', invoice: _invoice),
      isFalse,
    );
    expect(
      preimageMatchesInvoice(preimage: _preimage, invoice: 'not-an-invoice'),
      isFalse,
    );
    expect(
      preimageMatchesInvoice(preimage: '2a2a', invoice: _invoice),
      isFalse,
    );
  });
}
