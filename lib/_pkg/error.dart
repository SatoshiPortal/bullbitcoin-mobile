import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_ui/alert.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/routes.dart';

class Err {
  Err(
    this.message, {
    this.expected = false,
    this.title,
    this.solution,
    this.showAlert = false,
  }) {
    if (!expected) {
      var trace = StackTrace.current.toString();
      if (trace.length > 1000) trace = trace.substring(0, 1000);
      if (locator.isRegistered<Logger>()) locator<Logger>().log('Error: $message \n$trace');
    }
    if (showAlert) openAlert();
  }

  final String message;
  final bool expected;
  final String? title;
  final String? solution;
  final bool showAlert;

  @override
  String toString() =>
      (title != null ? '$title\nDetails: ' : '') +
      message +
      (solution != null ? '\nSolution: $solution' : '');

  void openAlert() => BBAlert.showErrorAlert(navigatorKey.currentContext!, err: toString());
}

extension X on Exception {
  String get message => (this as dynamic).message as String;
}
