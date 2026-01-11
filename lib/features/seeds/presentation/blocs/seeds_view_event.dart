abstract class SeedsViewEvent {}

class SeedsViewLoadRequested extends SeedsViewEvent {}

class SeedsViewDeleteRequested extends SeedsViewEvent {
  final String fingerprint;

  SeedsViewDeleteRequested({required this.fingerprint});
}

// TODO: Add event for deleting legacy seeds too
