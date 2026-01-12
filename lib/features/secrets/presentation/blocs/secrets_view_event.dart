abstract class SecretsViewEvent {}

class SecretsViewLoadRequested extends SecretsViewEvent {}

class SecretsViewDeleteRequested extends SecretsViewEvent {
  final String fingerprint;

  SecretsViewDeleteRequested({required this.fingerprint});
}

// TODO: Add event for deleting legacy seeds too
