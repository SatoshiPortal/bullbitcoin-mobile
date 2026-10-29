import '../../wallet_source_session.dart';
import '../wallet_source_registration.dart';

class DiscoverWalletHistoryRequest {
  final WalletSourceRegistration registration;

  /// Shell integration only: reuse an already admitted operation, never nest the same-key coordinator. The caller retains session ownership.
  final WalletSourceSession? session;
  const DiscoverWalletHistoryRequest(this.registration, {this.session});
}
