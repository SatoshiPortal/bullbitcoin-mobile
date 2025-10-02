import 'package:bb_mobile/features/utxos/application/dto/requests/get_utxo_request.dart';
import 'package:bb_mobile/features/utxos/application/dto/responses/get_utxo_response.dart';
import 'package:bb_mobile/features/utxos/application/dto/utxo_dto.dart';
import 'package:bb_mobile/features/utxos/domain/ports/labels_port.dart';
import 'package:bb_mobile/features/utxos/domain/ports/utxos_port.dart';
import 'package:bb_mobile/features/utxos/domain/ports/wallet_port.dart';

class GetUtxoUsecase {
  final LabelsPort _labelsPort;
  final WalletPort _walletPort;
  final UtxosPort _utxosPort;

  GetUtxoUsecase({
    required LabelsPort labelsPort,
    required WalletPort walletPort,
    required UtxosPort utxosPort,
  }) : _labelsPort = labelsPort,
       _walletPort = walletPort,
       _utxosPort = utxosPort;

  Future<GetUtxoResponse> execute(GetUtxoRequest request) async {
    final wallet = await _walletPort.getWallet(request.walletId);

    if (wallet == null) {
      throw Exception('Wallet not found');
    }

    final utxo = await _utxosPort.getUtxoFromWallet(
      txId: request.txId,
      index: request.index,
      wallet: wallet,
    );

    if (utxo == null) {
      throw Exception('UTXO not found');
    }

    // Fetch labels for the UTXO
    final (outputLabels, addressLabels, transactionLabels) =
        await (
          _labelsPort.getUtxoLabels(txId: utxo.txId, index: utxo.index),
          _labelsPort.getAddressLabels(utxo.address),
          _labelsPort.getTransactionLabels(utxo.txId),
        ).wait;

    final utxoDto = UtxoDto(
      walletId: request.walletId,
      walletName: wallet.displayLabel,
      txId: utxo.txId,
      index: utxo.index,
      address: utxo.address,
      valueSat: utxo.valueSat,
      isSpendable: outputLabels.firstOrNull?.spendable ?? true,
      outputLabels:
          outputLabels.map((e) => e.label).whereType<String>().toList(),
      addressLabels:
          addressLabels.map((e) => e.label).whereType<String>().toList(),
      transactionLabels:
          transactionLabels.map((e) => e.label).whereType<String>().toList(),
    );

    return GetUtxoResponse(utxo: utxoDto);
  }
}
