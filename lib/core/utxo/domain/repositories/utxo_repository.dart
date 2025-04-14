import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';

abstract class UtxoRepository {
  Future<List<Utxo>> getUtxos({
    required String origin,
  });
}
