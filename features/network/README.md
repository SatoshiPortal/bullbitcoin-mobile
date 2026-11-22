# Network

The network feature owns the Electrum, Mempool and Tor settings screens and service status. The host mounts it once during foreground setup with `NetworkFeature.mount(services: services, bindings: bindings)`, adds `feature.routes.root` to the root routes and adds `feature.routes.appSettings` beneath app settings. The host bindings, localization delegate and startup Tor diagnostics are available in `package:network/setup.dart`.

```dart
await NetworkNavigation.open(context, section: NetworkSection.tor);
```

The Electrum and Mempool routes borrow the capabilities opened by the host. Electrum settings read the current app environment through the mount bindings and keep that network on server operations. Service status probes Electrum on the default wallet's network and keeps the Bitcoin fee path as the Mempool probe.

Each service-status consumer creates and closes its own session.

```dart
final session = feature.status.session();
final subscription = session.watch().listen(onStatusUpdate);
try {
  final result = await session.check();
  // Handle Result<AllServicesStatus, NetworkFailure>.
} finally {
  await subscription.cancel();
  await session.close();
}
```

`watch()` replays the current snapshot and any current failure. `check()` probes the default wallet's network and publishes loading, partial rows and the final result. The session keeps the latest available rows across refreshes and failures. A newer check supersedes an older one within the same session. A superseded or closed check returns `StatusCheckInterruptedFailure` to its caller. Tor settings keep the Tor capability's existing connection state.
