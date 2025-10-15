import 'package:bb_mobile/core/errors/bull_exception.dart';

class TemplateError extends BullException {
  TemplateError(super.message);
}

class NoIpAddressError extends TemplateError {
  NoIpAddressError() : super('No IP address found');
}

class NoCachedIpError extends TemplateError {
  NoCachedIpError() : super('No IP cached');
}
