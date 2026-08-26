import 'package:bull_recoverbull/src/public/recoverbull.dart';

final class RecoverBullLog {
  RecoverBullLogger? _delegate;

  RecoverBullLog();

  void configure(RecoverBullLogger delegate) => _delegate = delegate;

  void fine(String message, {Object? error, StackTrace? trace}) {
    _delegate?.fine(message, error: error, trace: trace);
  }

  void info(String message, {Object? error, StackTrace? trace}) {
    _delegate?.info(message, error: error, trace: trace);
  }

  void warning(String message, {Object? error, StackTrace? trace}) {
    _delegate?.warning(message, error: error, trace: trace);
  }

  void severe({String? message, Object? error, StackTrace? trace}) {
    _delegate?.error(
      message ?? 'recoverbull.unexpected',
      error: error,
      trace: trace,
    );
  }
}

final log = RecoverBullLog();
