class TemplateError implements Exception {
  final String message;
  TemplateError(this.message);

  @override
  String toString() => message;
}

class NoIpAddressError extends TemplateError {
  NoIpAddressError() : super('No IP address found');
}

class NoCachedIpError extends TemplateError {
  NoCachedIpError() : super('No IP cached');
}
