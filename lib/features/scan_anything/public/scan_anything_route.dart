enum ScanAnythingRoute {
  scanAnything('/scan-anything'),
  scanAnythingResult('result');

  const ScanAnythingRoute(this.path);

  final String path;
}
