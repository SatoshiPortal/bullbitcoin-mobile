import 'package:bb_mobile/features/sp/data/mappers/sp_tx_draft_mapper.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  group('SpTxDraftMapper.toDomain', () {
    test('maps the inputs, the outputs and both amounts', () {
      final draft = SpTxDraftMapper.toDomain(
        bwk.TxSimulation(
          inputs: [
            bwk.UnifiedCoinView(
              source: bwk.CoinSource.sp,
              outpoint: 'aaaa:0',
              amountSat: BigInt.from(9000),
              height: 800000,
              status: bwk.UnifiedCoinStatus.unspent,
            ),
            bwk.UnifiedCoinView(
              source: bwk.CoinSource.taproot,
              outpoint: 'bbbb:1',
              amountSat: BigInt.from(1000),
              status: bwk.UnifiedCoinStatus.unconfirmed,
            ),
          ],
          outputs: [
            bwk.RecipientView.sp(
              address: 'sp1qexample',
              amountSat: BigInt.from(5000),
              label: 1,
              isMax: false,
            ),
            bwk.RecipientView.standard(
              address: 'bc1qexample',
              amountSat: BigInt.from(3000),
              isMax: false,
            ),
          ],
          feeSat: BigInt.from(250),
          changeSat: BigInt.from(1750),
        ),
        'draft-1',
      );

      expect(draft.id, 'draft-1');
      expect(draft.feeSat, Sats.fromInt(250));
      expect(draft.changeSat, Sats.fromInt(1750));

      expect(draft.inputs, hasLength(2));
      expect(draft.inputs.first.outpoint, (txId: 'aaaa', vout: 0));
      expect(draft.inputs.first.source, SpCoinSource.sp);
      expect(draft.inputs.last.status, SpCoinStatus.unconfirmed);

      expect(draft.outputs, hasLength(2));
      expect(draft.outputs.first, isA<SpRecipientSp>());
      expect((draft.outputs.first as SpRecipientSp).label, 1);
      expect(draft.outputs.last, isA<SpRecipientStandard>());
      expect(draft.outputs.last.amountSat, Sats.fromInt(3000));
    });

    test('maps a draft with no change', () {
      final draft = SpTxDraftMapper.toDomain(
        bwk.TxSimulation(
          inputs: const [],
          outputs: const [],
          feeSat: BigInt.from(100),
          changeSat: BigInt.zero,
        ),
        'draft-2',
      );

      expect(draft.inputs, isEmpty);
      expect(draft.outputs, isEmpty);
      expect(draft.changeSat, Sats.zero);
      expect(draft.feeSat, Sats.fromInt(100));
    });
  });
}
