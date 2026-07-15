import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/data/mappers/wallet_utxo_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletUtxoMapper', () {
    test(
      'liquid model round-trips the asset id, address index and factors',
      () {
        final model =
            WalletUtxoModel.liquid(
                  txId: 'a' * 64,
                  vout: 1,
                  amountSat: BigInt.from(1500),
                  scriptPubkey: '0014${'0' * 40}',
                  standardAddress: 'ex1qstandard',
                  confidentialAddress: 'lq1qconfidential',
                  assetIdHex: 'b' * 64,
                  addressIndex: 7,
                  valueBf: 'c' * 64,
                  assetBf: 'd' * 64,
                )
                as LiquidWalletUtxoModel;

        final entity = WalletUtxoMapper.toEntity(model, walletId: 'wallet-1');
        expect(entity, isA<LiquidWalletUtxo>());
        final liquid = entity as LiquidWalletUtxo;
        expect(liquid.assetIdHex, 'b' * 64);
        expect(liquid.addressIndex, 7);
        expect(liquid.valueBf, 'c' * 64);
        expect(liquid.assetBf, 'd' * 64);
        expect(liquid.amountSat, BigInt.from(1500));

        final roundTripped =
            WalletUtxoMapper.fromEntity(entity) as LiquidWalletUtxoModel;
        expect(roundTripped.assetIdHex, model.assetIdHex);
        expect(roundTripped.addressIndex, model.addressIndex);
        expect(roundTripped.valueBf, model.valueBf);
        expect(roundTripped.assetBf, model.assetBf);
        expect(roundTripped.txId, model.txId);
        expect(roundTripped.vout, model.vout);
      },
    );

    test('liquid address index may be null for foreign outputs', () {
      final model = WalletUtxoModel.liquid(
        txId: 'e' * 64,
        vout: 0,
        amountSat: BigInt.from(1000),
        scriptPubkey: '0014${'1' * 40}',
        standardAddress: 'ex1qstandard',
        confidentialAddress: 'lq1qconfidential',
        assetIdHex: 'f' * 64,
        addressIndex: null,
        valueBf: '1' * 64,
        assetBf: '2' * 64,
      );

      final liquid =
          WalletUtxoMapper.toEntity(model, walletId: 'wallet-1')
              as LiquidWalletUtxo;
      expect(liquid.addressIndex, isNull);
    });

    test('bitcoin utxo mapping is unaffected by the new liquid fields', () {
      final model = WalletUtxoModel.bitcoin(
        txId: '9' * 64,
        vout: 2,
        amountSat: BigInt.from(2500),
        scriptPubkey: Uint8List.fromList(List<int>.filled(22, 0)),
        address: 'bc1qexample',
        isExternalKeyChain: true,
      );

      final entity = WalletUtxoMapper.toEntity(model, walletId: 'wallet-1');
      expect(entity, isA<BitcoinWalletUtxo>());
      final roundTripped =
          WalletUtxoMapper.fromEntity(entity) as BitcoinWalletUtxoModel;
      expect(roundTripped.txId, model.txId);
      expect(roundTripped.amountSat, model.amountSat);
    });
  });
}
