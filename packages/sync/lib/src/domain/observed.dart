/// A value the engine publishes. [now] reads the last published value
/// synchronously, with no IO, native call or mapping. [watch] emits that value
/// first, then each change, and never re-reads the wallet per subscriber.
abstract interface class Observed<T> {
  T get now;
  Stream<T> watch();
}
