import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:dio/dio.dart';

final class AppPayjoinLogAdapter implements PayjoinLogPort {
  static const _displayedSessionRefLength = 7;

  const AppPayjoinLogAdapter();

  @override
  void write(PayjoinLogEvent event) {
    final message = _describe(event);
    switch (event.level) {
      case PayjoinLogLevel.info:
        log.info(message);
      case PayjoinLogLevel.fine:
        log.fine(message);
      case PayjoinLogLevel.warning:
        log.warning(message);
      case PayjoinLogLevel.severe:
        // Sentry must not receive arbitrary exception text either. Group by
        // structured code and cause type, retaining the original stack.
        log.severe(
          message: message,
          error: event.code.name,
          trace: event.trace ?? StackTrace.current,
        );
    }
  }

  /// Shows the role and a short correlation prefix before the event description; the structured event retains its full reference.
  /// Foreign exception text can contain transaction IDs, payment URIs or custom server URLs, so it never appears.
  static String _describe(PayjoinLogEvent event) {
    final role = event.role;
    final sessionRef = event.sessionRef;
    final error = event.error;
    return [
      'Payjoin',
      ?role?.name,
      if (sessionRef != null)
        sessionRef.substring(0, _displayedSessionRefLength),
      '${event.code.name}: ${event.code.description}',
      if (error != null) 'cause=${_describeCause(error)}',
    ].join(' ');
  }

  /// A transport failure says whether the directory or relay could not be
  /// reached, timed out or answered with an error status; its message is
  /// dropped because it quotes the URL.
  static String _describeCause(Object error) => switch (error) {
    DioException(:final type, :final response) =>
      'transport_${type.name}'
          '${response == null ? '' : '(${response.statusCode})'}',
    _ => 'operation',
  };
}
