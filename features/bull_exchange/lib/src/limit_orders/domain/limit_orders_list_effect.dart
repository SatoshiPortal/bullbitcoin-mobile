import 'package:meta/meta.dart';

@immutable
sealed class LimitOrdersListEffect {
  const LimitOrdersListEffect();
}

final class ListFetch extends LimitOrdersListEffect {
  final int attempt;

  const ListFetch(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ListFetch && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ListFetch, attempt);
}

final class ListCancelAll extends LimitOrdersListEffect {
  final int attempt;

  const ListCancelAll(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is ListCancelAll && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(ListCancelAll, attempt);
}
