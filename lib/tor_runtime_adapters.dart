import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor_adapter.dart';

/// The host's Tor logging routes; native failures stay in support logs.
TorLogger createTorLogger(Logger logger) => TorLogger(
  infoCallback: logger.info,
  configCallback: logger.config,
  fineCallback: logger.fine,
  warningCallback: logger.warning,
);
