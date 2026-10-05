import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Outpoint;

class ValidateBitcoinSelectionUsecase {
  final PayjoinSessions _payjoin;
  final WalletUtxoRepository _walletUtxoRepository;

  ValidateBitcoinSelectionUsecase({
    required PayjoinSessions payjoinSessions,
    required this._walletUtxoRepository,
  }) : _payjoin = payjoinSessions;

  Future<List<Outpoint>> execute({
    required String walletId,
    List<WalletUtxo>? selectedInputs,
  }) async {
    try {
      final userFrozen = await _walletUtxoRepository.getAllFrozenOutpoints();
      final payjoinResult = await _payjoin.reservedOutpoints();
      final payjoinReserved = switch (payjoinResult) {
        Ok(:final value) => value,
        Err() => throw ValidateBitcoinSelectionException(
          'Failed to load Payjoin-reserved UTXOs',
        ),
      };
      final unspendable = {...userFrozen, ...payjoinReserved};

      if (selectedInputs != null && selectedInputs.isNotEmpty) {
        final liveUtxos = await _walletUtxoRepository.getWalletUtxos(
          walletId: walletId,
        );
        final spendableOutpoints = liveUtxos
            .where(
              (utxo) => !utxo.isFrozen && !unspendable.contains(utxo.outpoint),
            )
            .map((utxo) => utxo.outpoint)
            .toSet();
        if (selectedInputs.any(
          (utxo) => !spendableOutpoints.contains(utxo.outpoint),
        )) {
          throw NoSpendableUtxoException(
            'A selected coin is no longer spendable',
          );
        }
      }

      return unspendable.toList();
    } on NoSpendableUtxoException {
      rethrow;
    } on ValidateBitcoinSelectionException {
      rethrow;
    } catch (error) {
      throw ValidateBitcoinSelectionException(error.toString());
    }
  }
}

class ValidateBitcoinSelectionException extends BullException {
  ValidateBitcoinSelectionException(super.message);
}
