/// What one sync saw for one topic: event identities only, never text.
final class Observation {
  final String topicId;
  final Set<String> eventIds;

  Observation(this.topicId, Iterable<String> eventIds)
    : eventIds = Set.unmodifiable(eventIds) {
    if (topicId.isEmpty || this.eventIds.any((id) => id.isEmpty)) {
      throw ArgumentError('Observation identities must not be empty');
    }
  }
}
