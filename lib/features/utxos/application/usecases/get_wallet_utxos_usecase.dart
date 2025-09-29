import 'package:bb_mobile/features/utxos/application/dto/requests/get_wallet_utxos_request.dart';
import 'package:bb_mobile/features/utxos/application/dto/responses/get_wallet_utxos_response.dart';
import 'package:bb_mobile/features/utxos/application/dto/utxo_dto.dart';
import 'package:bb_mobile/features/utxos/domain/ports/labels_port.dart';
import 'package:bb_mobile/features/utxos/domain/ports/wallets_port.dart';

class GetWalletUtxosUseCase {
  final LabelsPort _labelsPort;
  final WalletsPort _walletsPort;

  GetWalletUtxosUseCase({
    required LabelsPort labelsPort,
    required WalletsPort walletsPort,
  }) : _labelsPort = labelsPort,
       _walletsPort = walletsPort;

  Future<GetWalletUtxosResponse> execute(GetWalletUtxosRequest request) async {
    // TODO: Implement pagination using request.limit and request.offset
    final utxos = await _walletsPort.getUtxos(request.walletId);

    // Fetch labels for each UTXO
    final utxoDtos = await Future.wait(
      utxos.map((utxo) async {
        final (labels, addressLabels, transactionLabels) =
            await (
              _labelsPort.getUtxoLabels(txId: utxo.txId, index: utxo.index),
              _labelsPort.getAddressLabels(utxo.address),
              _labelsPort.getTransactionLabels(utxo.txId),
            ).wait;

        return UtxoDto(
          walletId: request.walletId,
          txId: utxo.txId,
          index: utxo.index,
          valueSat: utxo.valueSat,
          isSpendable: labels.firstOrNull?.isSpendable ?? true,
          labels: labels.map((e) => e.label).whereType<String>().toList(),
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
