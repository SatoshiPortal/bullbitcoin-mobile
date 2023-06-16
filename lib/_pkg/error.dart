import 'package:flutter/foundation.dart';

class Err {
  Err(this.message, {this.expected = false}) {
    if (!expected) {
      final trace = StackTrace.current;
      debugPrint('Error: $message \n$trace');
    }
  }

  final String message;
  final bool expected;

  @override
  String toString() => message;
}
