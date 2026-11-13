import 'dart:math';

import 'package:bull_sdk/bdk.dart' as bdk;

int electrumMedianTimePast({
  required bdk.ElectrumClient client,
  required int height,
  bdk.Header? knownHeader,
}) {
  final firstHeight = max(0, height - 10);
  final times = <int>[];
  for (
    var currentHeight = firstHeight;
    currentHeight <= height;
    currentHeight++
  ) {
    final header = currentHeight == height && knownHeader != null
        ? knownHeader
        : client.blockHeader(height: currentHeight);
    times.add(header.time);
  }
  times.sort();
  return times[times.length ~/ 2];
}
