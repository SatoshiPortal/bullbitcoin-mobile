import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppBlocObserver extends BlocObserver {
  AppBlocObserver();

  final _showConsoleLogs = false;

  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    if (_showConsoleLogs) log.fine('Bloc ${bloc.runtimeType} created');
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    if (_showConsoleLogs) {
      log.fine('Event ${event.runtimeType} added to bloc ${bloc.runtimeType}');
    }
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (_showConsoleLogs) {
      // Types only: full states embed exchange account data (user summary
      // with groups and balances) and the on-device log can be exported.
      log.fine(
        'State in bloc ${bloc.runtimeType} changed from '
        '${change.currentState.runtimeType} to '
        '${change.nextState.runtimeType}',
      );
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    if (_showConsoleLogs) {
      // Type only: the raw error can carry a full API response body.
      log.severe(
        message: 'Error in bloc ${bloc.runtimeType}',
        error: error.runtimeType,
        trace: stackTrace,
      );
    }
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    if (_showConsoleLogs) {
      log.fine(
        'Transition in bloc ${bloc.runtimeType}: '
        '${transition.event.runtimeType} -> '
        '${transition.nextState.runtimeType}',
      );
    }
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    if (_showConsoleLogs) log.fine('Bloc ${bloc.runtimeType} closed');
  }
}
