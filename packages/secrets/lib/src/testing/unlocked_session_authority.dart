import '../domain/session_authority.dart';

/// A session that already authenticated, for tests whose subject is not the
/// lock. Tests of the lock itself build a [SessionAuthority] and drive it
/// through a real inventory.
SessionAuthority unlockedSessionAuthority() => SessionAuthority()..grant('all');
