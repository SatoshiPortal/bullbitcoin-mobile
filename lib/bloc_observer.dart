import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Todo: change these debugPrints to persist logs
class AppBlocObserver extends BlocObserver {
  AppBlocObserver();

  final _showConsoleLogs = false;

  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    if (_showConsoleLogs) log.info('Bloc ${bloc.runtimeType} created');
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    if (_showConsoleLogs) {
      log.info('Event $event added to bloc ${bloc.runtimeType}');
    }
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (_showConsoleLogs) {
      log.info(
        'State in bloc ${bloc.runtimeType} changed from ${change.currentState} to ${change.nextState}',
      );
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    if (_showConsoleLogs) {
      log.severe(
        'Error in bloc ${bloc.runtimeType}: $error',
        trace: stackTrace,
      );
    }
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    if (_showConsoleLogs) {
      log.info('Transition in bloc ${bloc.runtimeType}: $transition');
    }
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    if (_showConsoleLogs) log.info('Bloc ${bloc.runtimeType} closed');
  }
}
