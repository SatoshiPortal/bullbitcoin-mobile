abstract class SecretsViewEvent {
  const SecretsViewEvent();
}

class SecretsViewLoadRequested extends SecretsViewEvent {
  const SecretsViewLoadRequested();
}

class SecretsViewDeleteRequested extends SecretsViewEvent {
  final String fingerprint;

  const SecretsViewDeleteRequested({required this.fingerprint});
}

// TODO: Add event for deleting legacy seeds too
