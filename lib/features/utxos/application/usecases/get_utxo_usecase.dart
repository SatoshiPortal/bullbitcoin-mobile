import 'package:bb_mobile/features/utxos/application/dto/requests/get_utxo_request.dart';
import 'package:bb_mobile/features/utxos/application/dto/responses/get_utxo_response.dart';
import 'package:bb_mobile/features/utxos/application/dto/utxo_dto.dart';
import 'package:bb_mobile/features/utxos/domain/ports/labels_port.dart';
import 'package:bb_mobile/features/utxos/domain/ports/wallets_port.dart';

class GetUtxoUseCase {
  final LabelsPort _labelsPort;
  final WalletsPort _walletsPort;

  GetUtxoUseCase({
    required LabelsPort labelsPort,
    required WalletsPort walletsPort,
  }) : _labelsPort = labelsPort,
       _walletsPort = walletsPort;

  Future<GetUtxoResponse> execute(GetUtxoRequest request) async {
    // TODO: Implement pagination using request.limit and request.offset
    final utxo = await _walletsPort.getUtxo(
      request.walletId,
      request.txId,
      request.index,
    );

    if (utxo == null) {
      throw Exception('UTXO not found');
    }

    // Fetch labels for the UTXO
    final (labels, addressLabels, transactionLabels) =
        await (
          _labelsPort.getUtxoLabels(txId: utxo.txId, index: utxo.index),
          _labelsPort.getAddressLabels(utxo.address),
          _labelsPort.getTransactionLabels(utxo.txId),
        ).wait;

    final utxoDto = UtxoDto(
      walletId: request.walletId,
      txId: utxo.txId,
      index: utxo.index,
      valueSat: utxo.valueSat,
      isSpendable: labels.firstOrNull?.isSpendable ?? true,
      labels: labels.map((e) => e.label).whereType<String>().toList(),
      addressLabels:
          addressLabels.map((e) => e.label).whereType<String>().toList(),
      transactionLabels:
          transactionLabels.map((e) => e.label).whereType<String>().toList(),
    );

    return GetUtxoResponse(utxo: utxoDto);
  }
}
