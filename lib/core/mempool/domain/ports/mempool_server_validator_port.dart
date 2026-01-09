import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';

abstract class MempoolServerValidatorPort {
  Future<bool> validateServer({
    required String url,
    required MempoolServerNetwork network,
  });
}
