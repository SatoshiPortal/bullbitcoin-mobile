/// One route: the flow's pages are a function of its state
/// (`SellFlowShell`), so no sub-route takes the bloc from `state.extra`.
enum SellRoute {
  sell('/sell');

  final String path;

  const SellRoute(this.path);
}
