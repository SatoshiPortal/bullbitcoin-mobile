import 'package:transaction_sync/transaction_sync.dart';

final class WatchCbfNetworkPolicyUsecase {
  final CbfNetworkPolicyPort _policy;

  const WatchCbfNetworkPolicyUsecase({required this._policy});

  Stream<CbfNetworkPolicyState> execute() => _policy.watch();
}
