import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_datasource.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';

class ListJoinstrPoolsUsecase {
  final JoinstrDatasource _datasource;

  ListJoinstrPoolsUsecase({required this._datasource});

  Future<List<JoinstrPool>> execute({
    String? relay,
    Duration back = const Duration(days: 1),
    Duration wait = const Duration(seconds: 5),
  }) async {
    final pools = await _datasource.listPools(
      relay: relay ?? ApiServiceConstants.defaultNostrRelayUrl,
      back: back,
      wait: wait,
    );
    pools.sort((a, b) => a.denominationSat.compareTo(b.denominationSat));
    return pools;
  }
}
