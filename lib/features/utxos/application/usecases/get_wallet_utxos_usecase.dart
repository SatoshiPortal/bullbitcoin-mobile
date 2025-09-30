import 'package:bb_mobile/core/labels/domain/ports/labels_port.dart';
import 'package:bb_mobile/core/wallet/domain/ports/wallet_port.dart';
import 'package:bb_mobile/features/utxos/application/dto/requests/get_wallet_utxos_request.dart';
import 'package:bb_mobile/features/utxos/application/dto/responses/get_wallet_utxos_response.dart';
import 'package:bb_mobile/features/utxos/application/dto/utxo_dto.dart';
import 'package:bb_mobile/features/utxos/domain/ports/utxos_port.dart';

class GetWalletUtxosUsecase {
  final LabelsPort _labelsPort;
  final WalletPort _walletPort;
  final UtxosPort _utxosPort;

  GetWalletUtxosUsecase({
    required LabelsPort labelsPort,
    required WalletPort walletPort,
    required UtxosPort utxosPort,
  }) : _labelsPort = labelsPort,
       _walletPort = walletPort,
       _utxosPort = utxosPort;

  Future<GetWalletUtxosResponse> execute(GetWalletUtxosRequest request) async {
    final wallet = await _walletPort.getWallet(request.walletId);

    if (wallet == null) {
      throw Exception('Wallet not found');
    }

    // TODO: Implement pagination using request.limit and request.offset
    final utxos = await _utxosPort.getUtxosFromWallet(wallet);

    // Fetch labels for each UTXO
    final utxoDtos = await Future.wait(
      utxos.map((utxo) async {
        final (outputLabels, addressLabels, transactionLabels) =
            await (
              _labelsPort.getUtxoLabels(txId: utxo.txId, index: utxo.index),
              _labelsPort.getAddressLabels(utxo.address),
              _labelsPort.getTransactionLabels(utxo.txId),
            ).wait;

        return UtxoDto(
          walletId: request.walletId,
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
              transactionLabels
                  .map((e) => e.label)
                  .whereType<String>()
                  .toList(),
        );
      }).toList(),
    );

    return GetWalletUtxosResponse(utxos: utxoDtos);
  }
}
