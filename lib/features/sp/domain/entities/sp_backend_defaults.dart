/// Backend (blindbit + electrum) default URLs for a network. The repository
/// returns a `Result`, so failure lives in the `Result`, not in this holder.
class SpBackendDefaults {
  final String blindbitUrl;
  final String electrumUrl;

  const SpBackendDefaults({
    required this.blindbitUrl,
    required this.electrumUrl,
  });
}
