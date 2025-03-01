import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Todo: change these debugPrints to persist logs
class AppBlocObserver extends BlocObserver {
  AppBlocObserver();

  final _showConsoleLogs = false;

  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    if (_showConsoleLogs) debugPrint('Bloc ${bloc.runtimeType} created');
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    if (_showConsoleLogs) {
      debugPrint('Event $event added to bloc ${bloc.runtimeType}');
    }
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (_showConsoleLogs) {
      debugPrint(
        'State in bloc ${bloc.runtimeType} changed from ${change.currentState} to ${change.nextState}',
      );
    }
  }

  @override
  void onError(
    BlocBase bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    super.onError(bloc, error, stackTrace);
    if (_showConsoleLogs) {
      debugPrint(
        'Error in bloc ${bloc.runtimeType}: $error with stack trace: $stackTrace',
      );
    }
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    if (_showConsoleLogs) {
      debugPrint('Transition in bloc ${bloc.runtimeType}: $transition');
    }
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    if (_showConsoleLogs) debugPrint('Bloc ${bloc.runtimeType} closed');
  }
}
