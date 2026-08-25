/// What the app shell composes: registration into the service locator, the
/// lifecycle hook, and the logging seam.
///
/// Features must not import this library — see `tor.dart`.
library;

export 'src/data/tor_logger.dart';
// The port behind `VerifyExternalTorUsecase`. That use-case is `final`, so a
// consumer's test cannot mock it: substituting the external proxy means substituting the port. Published here rather than from `tor.dart` because a feature must keep going through the use-case.
export 'src/domain/ports/external_tor_port.dart';
export 'src/tor_lifecycle_controller.dart';
export 'src/tor_locator.dart';
