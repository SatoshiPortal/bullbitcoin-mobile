import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:primitives/primitives.dart';

/// Internal composition guard. Routing preference is not maintenance authority.
final class ArkNetworkExecutionPolicy implements ArkExecutionPolicyPort {
  final ArkExecutionPolicyPort _delegate;
  const ArkNetworkExecutionPolicy(this._delegate);

  @override
  bool mayRun(ArkAccountId account, ArkExecutionMode mode) =>
      NetworkCapabilities.supports(account.network, NetworkCapability.ark) &&
      _delegate.mayRun(account, mode);
}
