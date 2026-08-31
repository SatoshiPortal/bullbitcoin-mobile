import 'dart:developer' as developer;

class _SwapLog {
  const _SwapLog();

  void info(Object? message, {Object? error, StackTrace? trace}) => developer
      .log('$message', name: 'bull_swap', error: error, stackTrace: trace);

  void warning(Object? message, {Object? error, StackTrace? trace}) =>
      developer.log(
        '$message',
        name: 'bull_swap',
        level: 900,
        error: error,
        stackTrace: trace,
      );
}

const log = _SwapLog();
