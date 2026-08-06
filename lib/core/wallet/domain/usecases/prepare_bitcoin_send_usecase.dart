import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Outpoint;

class PrepareBitcoinSendUsecase {
  final PayjoinSessions _payjoin;
  final BitcoinSendPort _bitcoinWalletRepository;
  final WalletUtxoRepository _walletUtxoRepository;

  PrepareBitcoinSendUsecase({
    required PayjoinSessions payjoinSessions,
    required this._walletUtxoRepository,
    required this._bitcoinWalletRepository,
  }) : _payjoin = payjoinSessions;

  Future<({String unsignedPsbt, int txSize, bool isToSelf})> execute({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    List<WalletUtxo>? selectedInputs,
    bool replaceByFee = true,
  }) async {
    try {
      if (amountSat == null && drain == false) {
        throw Exception('Amount cannot be empty if drain is not true');
      }

      // D7: a frozen coin must never be spendable in any transaction. Always
      // compute the unspendable set (user-frozen ∪ payjoin-derived) and feed it
      // to every PSBT build (normal send + drain). The two sources are kept
      // explicit on purpose; the future payjoin-unification collapses
      // `_unspendableFor` to a single read.
      final unspendableUtxos = await _unspendableFor(walletId);

      log.info(
        'Bitcoin wallet id $walletId building psbt. Unspendable utxos: $unspendableUtxos',
      );

      // Belt-and-suspenders: defensively strip any selected input that falls in
      // the unspendable set before building (guards a future send-from-selected
      // path from ever pinning a frozen coin).
      final filteredSelectedInputs = selectedInputs
          ?.where(
            (utxo) =>
                !unspendableUtxos.contains((txId: utxo.txId, vout: utxo.vout)),
          )
          .toList();

      final psbt = await _bitcoinWalletRepository.buildPsbt(
        walletId: walletId,
        address: address,
        amountSat: amountSat,
        networkFee: networkFee,
        drain: drain,
        unspendable: unspendableUtxos,
        selected: filteredSelectedInputs,
        replaceByFee: replaceByFee,
      );
      final size = await _bitcoinWalletRepository.getTxSize(psbt: psbt);
      final isToSelf = await _bitcoinWalletRepository.isAddressOfWallet(
        address,
        walletId: walletId,
      );
      return (unsignedPsbt: psbt, txSize: size, isToSelf: isToSelf);
    } on NoSpendableUtxoException {
      rethrow;
    } catch (e) {
      throw PrepareBitcoinSendException(e.toString());
    }
  }

  /// The set of outpoints that must never be spent for [walletId]:
  /// dedup(user-frozen ∪ payjoin-derived). Two explicit sources by design
  /// (§6.1) — this is the single seam the future payjoin-unification collapses
  /// to one read.
  Future<List<Outpoint>> _unspendableFor(String walletId) async {
    // Freeze is matched by outpoint (globally unique), so the full frozen set
    // is safe to pass: buildPsbt ignores any outpoint this wallet doesn't own.
    final userFrozen = await _walletUtxoRepository.getAllFrozenOutpoints();
    final payjoinResult = await _payjoin.reservedOutpoints();
    final payjoinFrozen = switch (payjoinResult) {
      Ok(:final value) => value,
      Err() => throw PrepareBitcoinSendException(
        'Failed to load Payjoin-reserved UTXOs',
      ),
    };
    return {...userFrozen, ...payjoinFrozen}.toList();
  }
}

class PrepareBitcoinSendException extends BullException {
  PrepareBitcoinSendException(super.message);
}
