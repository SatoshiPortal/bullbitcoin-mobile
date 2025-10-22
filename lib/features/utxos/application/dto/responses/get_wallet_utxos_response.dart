import 'package:bb_mobile/features/utxos/application/dto/utxo_dto.dart';

class GetWalletUtxosResponse {
  final List<UtxoDto> utxos;

  GetWalletUtxosResponse({required this.utxos});
}
