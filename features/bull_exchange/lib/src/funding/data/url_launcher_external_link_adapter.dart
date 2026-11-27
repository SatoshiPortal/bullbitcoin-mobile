import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/funding/domain/external_link_port.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:url_launcher/url_launcher.dart';

/// `url_launcher`-backed [ExternalLinkPort].
///
/// This is the one `try/catch` boundary for opening a link: the platform call
/// is awaited here, so a rejected launch becomes a `Result` instead of an
/// unhandled asynchronous error.
class UrlLauncherExternalLinkAdapter implements ExternalLinkPort {
  const UrlLauncherExternalLinkAdapter();

  @override
  @useResult
  Future<Result<void, ExchangeFailure>> open(Uri url) async {
    try {
      final launched = await launchUrl(url, mode: LaunchMode.inAppBrowserView);

      if (!launched) {
        // No handler for the scheme — a normal device condition, not a bug.
        log.warning('No handler available for external link');
        return const Err(ExchangePaymentLinkUnavailableFailure());
      }

      return const Ok(null);
    } catch (e, st) {
      log.severe(message: 'Failed to open external link', error: e, trace: st);
      return Err(ExchangePaymentLinkUnavailableFailure(e.toString()));
    }
  }
}
