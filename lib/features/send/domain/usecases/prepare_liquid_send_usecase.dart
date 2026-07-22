import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/liquid_tx_output.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_build_tx_exceptions.dart';

class PrepareLiquidSendUsecase {
  final LiquidWalletRepository _liquidWalletRepository;
  final WalletUtxoRepository _walletUtxoRepository;
  final WalletAddressRepository _walletAddressRepository;

  PrepareLiquidSendUsecase({
    required this._liquidWalletRepository,
    required this._walletUtxoRepository,
    required this._walletAddressRepository,
  });

  Future<String> execute({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
  }) async {
    try {
      if (amountSat == null && drain == false) {
        throw Exception('Amount cannot be empty if drain is not true');
      }

      // Built via buildCustomTx (an explicit UTXO list) rather than the
      // LWK-coin-selecting buildPset, specifically so a frozen UTXO (e.g. a
      // consolidation decoy, which must never be re-spent — see the
      // consolidation feature) is never even offered to the builder, not
      // just excluded from the UI's own bookkeeping.
      final confirmed = await _liquidWalletRepository.getConfirmedLbtcOutpoints(
        walletId: walletId,
      );
      final frozen = (await _walletUtxoRepository.getAllFrozenOutpoints())
          .toSet();
      final usable = confirmed.where((o) => !frozen.contains(o)).toList();

      if (usable.isEmpty) {
        throw NoSpendableUtxoException(
          'Wallet $walletId has no spendable (confirmed, unfrozen) L-BTC '
          'UTXOs',
        );
      }
      if (_liquidWalletRepository.exceedsLiquidInputLimit(usable.length)) {
        throw ConsolidationRequiredException(
          'Wallet $walletId exceeds the Liquid confidential-tx input limit',
        );
      }

      // Drain (send-all): everything in the usable set goes to the
      // recipient, no change back to self. Normal send: pay the recipient,
      // sweep the rest to a freshly reserved address of our own — reserved
      // through WalletAddressRepository (not a raw index lookup) so this
      // doesn't race the receive flow's own address reservation.
      final outputs = drain
          ? const <LiquidTxOutput>[]
          : [LiquidTxOutput(address: address, satoshi: amountSat!)];
      final drainToAddress = drain
          ? address
          : (await _walletAddressRepository.generateNewReceiveAddress(
              walletId: walletId,
            )).address;

      final pset = await _liquidWalletRepository.buildCustomTx(
        walletId: walletId,
        utxos: usable,
        outputs: outputs,
        drainToAddress: drainToAddress,
        feeRate: feeRate,
      );
      return pset;
    } on NoSpendableUtxoException {
      rethrow;
    } on ConsolidationRequiredException {
      rethrow;
    } catch (e) {
      throw PrepareLiquidSendException(e.toString());
    }
  }
}

class PrepareLiquidSendException extends BullException {
  PrepareLiquidSendException(super.message);
}
