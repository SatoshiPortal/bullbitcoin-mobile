/// One route: the flow's pages are a function of its state
/// (`DcaFlowShell`), so no sub-route takes the bloc from `state.extra`.
enum DcaRoute {
  dca('/dca');

  final String path;

  const DcaRoute(this.path);
}
