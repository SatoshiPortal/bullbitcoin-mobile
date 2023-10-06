import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/locator.dart';

class Err {
  Err(this.message, {this.expected = false}) {
    if (!expected) {
      var trace = StackTrace.current.toString();
      if (trace.length > 1000) trace = trace.substring(0, 1000);
      locator<Logger>().log('Error: $message \n$trace');
    }
  }

  final String message;
  final bool expected;

  @override
  String toString() => message;
}
