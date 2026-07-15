import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_datasource.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_store.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';

class ListJoinstrPoolsUsecase {
  final JoinstrDatasource _datasource;
  final JoinstrStore _store;

  ListJoinstrPoolsUsecase({required this._datasource, required this._store});

  Future<List<JoinstrPool>> execute({
    String? relay,
    Duration back = const Duration(days: 1),
    Duration wait = const Duration(seconds: 5),
  }) async {
    final storedRelay = relay ?? await _store.getRelay();
    final pools = await _datasource.listPools(
      relay: storedRelay ?? ApiServiceConstants.defaultNostrRelayUrl,
      back: back,
      wait: wait,
    );

    // The relay returns every pool advertised in the last `back`, most of
    // which have already expired. An expired pool can never fill, so listing
    // it would offer a join that can only time out.
    final now = DateTime.now();
    final joinable = pools.where((p) => p.secondsUntilExpiry(now) > 0).toList()
      ..sort((a, b) => a.denominationSat.compareTo(b.denominationSat));
    return joinable;
  }
}
