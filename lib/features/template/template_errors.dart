class NoIpAddressError implements Exception {
  String message = 'No IP address found';

  @override
  String toString() => message;
}

class NoCachedIpError implements Exception {
  String message = 'No IP cached';

  @override
  String toString() => message;
}
