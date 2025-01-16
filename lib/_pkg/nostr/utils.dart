import 'dart:math';

import 'package:convert/convert.dart';

String generateHexBytes(int quantity) {
  final random = Random.secure();
  final bytes = List<int>.generate(quantity, (i) => random.nextInt(256));
  return hex.encode(bytes);
}
