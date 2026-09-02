import 'package:bb_mobile/features/sp/data/mappers/sp_recipient_mapper.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_address.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  group('SpRecipientMapper.toFfi', () {
    test('a silent payment recipient keeps its label and max flag', () {
      final view = SpRecipientMapper.toFfi(
        SpRecipientSp(
          address: SpAddress('sp1qexample'),
          amountSat: Sats.fromInt(5000),
          isMax: true,
          label: 3,
        ),
      );

      expect(view, isA<bwk.RecipientView_Sp>());
      final sp = view as bwk.RecipientView_Sp;
      expect(sp.address, 'sp1qexample');
      expect(sp.amountSat, BigInt.from(5000));
      expect(sp.label, 3);
      expect(sp.isMax, isTrue);
    });

    test('a silent payment recipient with no label sends a null label', () {
      final view =
          SpRecipientMapper.toFfi(
                SpRecipientSp(
                  address: SpAddress('sp1qexample'),
                  amountSat: Sats.fromInt(1),
                  isMax: false,
                ),
              )
              as bwk.RecipientView_Sp;

      expect(view.label, isNull);
      expect(view.isMax, isFalse);
    });

    test('a standard recipient maps to the standard variant', () {
      final view = SpRecipientMapper.toFfi(
        SpRecipientStandard(
          address: SpAddress('bc1qexample'),
          amountSat: Sats.fromInt(700),
          isMax: false,
        ),
      );

      expect(view, isA<bwk.RecipientView_Standard>());
      final standard = view as bwk.RecipientView_Standard;
      expect(standard.address, 'bc1qexample');
      expect(standard.amountSat, BigInt.from(700));
      expect(standard.isMax, isFalse);
    });
  });

  group('SpRecipientMapper.toDomain', () {
    test('the sp variant maps to SpRecipientSp', () {
      final recipient = SpRecipientMapper.toDomain(
        bwk.RecipientView.sp(
          address: 'tsp1qexample',
          amountSat: BigInt.from(120),
          label: 9,
          isMax: false,
        ),
      );

      expect(recipient, isA<SpRecipientSp>());
      final sp = recipient as SpRecipientSp;
      expect(sp.address.value, 'tsp1qexample');
      expect(sp.amountSat, Sats.fromInt(120));
      expect(sp.label, 9);
      expect(sp.isMax, isFalse);
    });

    test('the standard variant maps to SpRecipientStandard', () {
      final recipient = SpRecipientMapper.toDomain(
        bwk.RecipientView.standard(
          address: 'bcrt1qexample',
          amountSat: BigInt.from(88),
          isMax: true,
        ),
      );

      expect(recipient, isA<SpRecipientStandard>());
      final standard = recipient as SpRecipientStandard;
      expect(standard.address.value, 'bcrt1qexample');
      expect(standard.amountSat, Sats.fromInt(88));
      expect(standard.isMax, isTrue);
    });
  });

  group('SpRecipientMapper round trip', () {
    test('an sp view survives toDomain then toFfi unchanged', () {
      final view = bwk.RecipientView.sp(
        address: 'sp1qexample',
        amountSat: BigInt.from(31337),
        label: 2,
        isMax: true,
      );

      expect(SpRecipientMapper.toFfi(SpRecipientMapper.toDomain(view)), view);
    });

    test('a standard view survives toDomain then toFfi unchanged', () {
      final view = bwk.RecipientView.standard(
        address: 'bc1qexample',
        amountSat: BigInt.zero,
        isMax: false,
      );

      expect(SpRecipientMapper.toFfi(SpRecipientMapper.toDomain(view)), view);
    });
  });
}
