import 'package:transaction_sync/transaction_sync.dart';

final class ContinueCbfOnMobileDataUsecase {
  final CbfNetworkPolicyPort _policy;

  const ContinueCbfOnMobileDataUsecase({required this._policy});

  void execute() => _policy.continueOnMobileData();
}
