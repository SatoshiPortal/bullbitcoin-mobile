/// One route: the flow's pages are a function of its state
/// (`PayFlowShell`), so no sub-route takes the bloc from `state.extra`.
enum PayRoute {
  pay('/pay');

  final String path;

  const PayRoute(this.path);
}
