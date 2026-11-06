import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/exchange/domain/read_exchange_environment.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:meta/meta.dart';

/// The notification socket, as the cubit needs it.
///
/// No `try/catch` here: the repository is the boundary and already logged the
/// raw reason. The lifted failure exists so a caller *could* react, though the
/// socket is best-effort and the cubit deliberately does not surface it.
class WatchExchangeNotificationsUsecase {
  final SettingsRepository? _settingsRepository;
  final ExchangeNotificationRepository _exchangeNotificationRepository;

  const WatchExchangeNotificationsUsecase({
    required this._exchangeNotificationRepository,
    this._settingsRepository,
  });

  /// Emits whenever the server says the account may have changed.
  Stream<NotificationMessage> accountChanges() =>
      _exchangeNotificationRepository.messages.where(
        // The kinds that mean the cached account is stale. A `switch` rather
        // than a set, so a new kind has to be placed deliberately.
        (message) => switch (message.kind) {
          NotificationMessageKind.balance ||
          NotificationMessageKind.group ||
          NotificationMessageKind.kyc ||
          NotificationMessageKind.userPreferences => true,
          _ => false,
        },
      );

  @useResult
  Future<Result<void, ExchangeFailure>> connect() => _open(reconnect: false);

  @useResult
  Future<Result<void, ExchangeFailure>> reconnect() => _open(reconnect: true);

  Future<Result<void, ExchangeFailure>> _open({required bool reconnect}) async {
    final settingsRepository = _settingsRepository;
    if (settingsRepository == null) {
      return const Err(ExchangeNotificationsUnavailableFailure());
    }
    final allowed = await readExchangeEnvironment(
      settingsRepository,
      ExchangeNotificationsUnavailableFailure.new,
    );
    if (allowed case Err(:final failure)) {
      _exchangeNotificationRepository.disconnect();
      return Err(failure);
    }
    return (await (reconnect
            ? _exchangeNotificationRepository.reconnect()
            : _exchangeNotificationRepository.connect()))
        .mapErr(
          (failure) =>
              ExchangeNotificationsUnavailableFailure(failure.logMessage),
        );
  }

  void disconnect() => _exchangeNotificationRepository.disconnect();
}
