import '../repositories/exchange_access_repository.dart';

import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/exchange/domain/read_exchange_environment.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

/// The notification socket, as the cubit needs it.
///
/// The socket is best-effort and the cubit deliberately does not surface its
/// failures. Session access still governs when it is allowed to connect.
class WatchExchangeNotificationsUsecase {
  final Preferences _settingsRepository;
  final Exchange _exchange;
  final ExchangeAccessRepository _access;

  const WatchExchangeNotificationsUsecase({
    required this._exchange,
    required this._settingsRepository,
    required this._access,
  });

  /// Emits whenever the server says the account may have changed.
  Stream<NotificationMessage> accountChanges() =>
      _exchange.notifications.expand(
        (event) => switch (event) {
          Ok(value: final message)
              when switch (message.kind) {
                NotificationMessageKind.balance ||
                NotificationMessageKind.group ||
                NotificationMessageKind.kyc ||
                NotificationMessageKind.userPreferences => true,
                _ => false,
              } =>
            [message],
          _ => const [],
        },
      );

  /// The handshake stays outside the access queue so it cannot delay sign-out
  /// or trading. Sign-out, reconciliation and expiry disconnect, but an attempt
  /// may start after that disconnect (the service first reads settings), so a
  /// stale attempt closes the socket unless a new session is signed in.
  Future<Result<void, ExchangeFailure>> _open({required bool reconnect}) async {
    final token = _access.epoch;
    if (!_signedIn) return const Err(ExchangeNotAuthenticatedFailure());
    final allowed = await readExchangeEnvironment(
      _settingsRepository,
      ExchangeNotificationsUnavailableFailure.new,
    );
    if (token != _access.epoch || !_signedIn) {
      return const Err(ExchangeOperationStaleFailure());
    }
    if (allowed case Err(:final failure)) {
      _exchange.disconnectNotifications();
      return Err(failure);
    }
    final result = reconnect
        ? await _exchange.reconnectNotifications()
        : await _exchange.connectNotifications();
    if (token != _access.epoch) {
      if (!_signedIn) _exchange.disconnectNotifications();
      return const Err(ExchangeOperationStaleFailure());
    }
    return result;
  }

  bool get _signedIn => switch (_access.current) {
    ExchangeAccessEnabled(session: ExchangeAccessSession.signedIn) => true,
    _ => false,
  };

  @useResult
  Future<Result<void, ExchangeFailure>> connect() => _open(reconnect: false);

  @useResult
  Future<Result<void, ExchangeFailure>> reconnect() => _open(reconnect: true);

  void disconnect() => _exchange.disconnectNotifications();
}
