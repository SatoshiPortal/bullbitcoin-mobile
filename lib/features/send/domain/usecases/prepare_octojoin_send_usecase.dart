import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/send/domain/octojoin.dart';

class PrepareOctojoinSendUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;
  final WalletUtxoRepository _walletUtxoRepository;
  final PayjoinRepository _payjoin;

  PrepareOctojoinSendUsecase({
    required this._bitcoinWalletRepository,
    required this._walletUtxoRepository,
    required PayjoinRepository payjoinRepository,
  }) : _payjoin = payjoinRepository;

  Future<({String unsignedPsbt, int txSize})> execute({
    required Wallet wallet,
    required List<String> addresses,
    required int amountSat,
    required NetworkFee networkFee,
    required int numInputs,
    required List<WalletUtxo> utxos,
    bool replaceByFee = true,
  }) async {
    try {
      if (!wallet.network.isBitcoin) {
        throw OctojoinException(OctojoinIssue.bitcoinOnly);
      }

      final userFrozen = await _walletUtxoRepository.getAllFrozenOutpoints();
      final payjoinFrozen = await _payjoin.getUtxosFrozenByOngoingPayjoins();
      final unspendable = <Outpoint>{...userFrozen, ...payjoinFrozen};

      final spendable = utxos
          .where(
            (u) =>
                !u.isFrozen &&
                !unspendable.contains((txId: u.txId, vout: u.vout)),
          )
          .toList();

      final inputVbytes = Octojoin.inputVbytesForScriptType(wallet.scriptType);
      final feeForShape = switch (networkFee) {
        AbsoluteFee(:final sats) => (int _, int _) => sats,
        RelativeFee(:final satPerVbyte) =>
          (int numInputs, int numOutputs) => Octojoin.estimateFee(
            numInputs: numInputs,
            numOutputs: numOutputs,
            satPerVbyte: satPerVbyte,
            inputVbytes: inputVbytes,
          ),
      };

      final plan = Octojoin.plan(
        utxos: spendable,
        paymentSat: amountSat,
        addresses: addresses,
        numInputs: numInputs,
        feeForShape: feeForShape,
      );

      log.info(
        'Octojoin wallet id ${wallet.id} building psbt: '
        '${plan.inputs.length} inputs, ${plan.targets.length} payment outputs',
      );

      final psbt = await _bitcoinWalletRepository.buildMultiRecipientPsbt(
        walletId: wallet.id,
        recipients: plan.targets,
        networkFee: networkFee,
        inputs: plan.inputs,
        replaceByFee: replaceByFee,
      );
      final txSize = await _bitcoinWalletRepository.getTxSize(psbt: psbt);
      return (unsignedPsbt: psbt, txSize: txSize);
    } on OctojoinException {
      rethrow;
    } catch (e) {
      throw PrepareOctojoinSendException(e.toString());
    }
  }
}

class PrepareOctojoinSendException extends BullException {
  PrepareOctojoinSendException(super.message);
}
