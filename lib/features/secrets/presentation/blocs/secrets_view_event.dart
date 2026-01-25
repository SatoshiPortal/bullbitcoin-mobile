import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';

abstract class SecretsViewEvent {
  const SecretsViewEvent();
}

class SecretsViewLoadRequested extends SecretsViewEvent {
  const SecretsViewLoadRequested();
}

class SecretsViewDeleteRequested extends SecretsViewEvent {
  final Fingerprint fingerprint;

  const SecretsViewDeleteRequested({required this.fingerprint});
}

// TODO: Add event for deleting legacy seeds too
