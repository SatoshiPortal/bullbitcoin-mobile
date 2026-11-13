import 'package:bb_mobile/core/wallet/data/models/bitcoin_policy_maturity_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_maturity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_node.dart';

class BitcoinPolicyMaturityMapper {
  static BitcoinPolicyMaturity toEntity(BitcoinPolicyMaturityModel model) =>
      BitcoinPolicyMaturity(
        tipHeight: model.tipHeight,
        medianTimePast: model.medianTimePast,
        utxos: [
          for (final utxo in model.utxos)
            BitcoinPolicyUtxoMaturity(
              outpoint: utxo.outpoint,
              keychain: switch (utxo.keychain) {
                BitcoinPolicyKeychainModel.external =>
                  BitcoinPolicyKeychain.external,
                BitcoinPolicyKeychainModel.internal =>
                  BitcoinPolicyKeychain.internal,
              },
              amountSat: utxo.amountSat,
              confirmations: utxo.confirmations,
              confirmationMedianTimePast: utxo.confirmationMedianTimePast,
            ),
        ],
      );
}
