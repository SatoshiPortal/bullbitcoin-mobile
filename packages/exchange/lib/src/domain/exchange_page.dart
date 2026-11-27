/// One page of a list the exchange answered. [next] is the next page number,
/// or null on the last page. A list read answers
/// `Result<ExchangePage<T>, ExchangeListFailure>`: a failure is never an
/// empty page.
final class ExchangePage<T> {
  final List<T> items;
  final int? next;

  const ExchangePage(this.items, {this.next});
}
