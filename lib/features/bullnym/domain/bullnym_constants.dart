import 'dart:convert';

const bullnymDefaultDomain = 'bullpay.ca';
const bullnymDefaultBaseUrl = 'https://$bullnymDefaultDomain';

final bullnymNymRegex = RegExp(
  r'^(?:[a-z0-9]|[a-z0-9][a-z0-9\-]{0,30}[a-z0-9])$',
);

int bullnymUtf8ByteLength(String value) => utf8.encode(value).length;
