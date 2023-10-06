import 'package:flutter_bloc/flutter_bloc.dart';

class Logger extends Cubit<List<(String, DateTime)>> {
  Logger() : super([]);

  void log(String message, {bool printToConsole = false}) {
    emit([...state, (message, DateTime.now())]);
    if (printToConsole) print(message);
  }

  void clear() => emit([]);
}
