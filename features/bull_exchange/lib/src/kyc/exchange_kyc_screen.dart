import 'dart:async';
import 'dart:io';

import 'package:bull_ui/bull_ui.dart' show BullInfoCard, BullThemeX;
import 'package:exchange/exchange.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../auth/exchange_auth_machine.dart';
import 'exchange_kyc_host.dart';
import 'exchange_kyc_navigation.dart';

class ExchangeKycScreen extends StatefulWidget {
  final ExchangeKycHost host;

  const ExchangeKycScreen({super.key, required this.host});

  @override
  State<ExchangeKycScreen> createState() => _ExchangeKycScreenState();
}

class _ExchangeKycScreenState extends State<ExchangeKycScreen> {
  late final WebViewController _controller = WebViewController();
  ExchangeKycState _kyc = ExchangeKycState.browsing;
  bool _isLoadingConfiguration = true;
  ExchangeFailure? _configurationFailure;

  @override
  void initState() {
    super.initState();

    unawaited(_load());
  }

  void _leave(ExchangeKycEvent event) {
    final next = transitionKyc(_kyc, event);
    if (next == _kyc) return;
    _kyc = next;
    switch (next) {
      case ExchangeKycState.leaving:
        widget.host.onExit(context);
      case ExchangeKycState.browsing:
        break;
    }
  }

  Future<void> _retry() async {
    setState(() {
      _isLoadingConfiguration = true;
      _configurationFailure = null;
    });
    await _load();
  }

  Future<void> _load() async {
    final result = await widget.host.loadConfiguration();
    if (!mounted) return;
    final ExchangeKycConfiguration configuration;
    switch (result) {
      case Ok(:final value):
        configuration = value;
      case Err(:final failure):
        setState(() {
          _isLoadingConfiguration = false;
          _configurationFailure = failure;
        });
        return;
    }
    final navigation = ExchangeKycNavigation(configuration.url.toString());
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) {
            if (!mounted) return;
            final url = navigation.resolve(change.url ?? '');
            if (url == null) return;

            final isIncodeSmile = navigation.isIncode(url);
            final allow = navigation.allows(url);

            // Anything that is not a KYC or login URL should not be allowed and
            //  may indicate that the user is trying to leave the KYC flow, either
            //  after completing it or by trying to close the KYC flow from
            //  within the WebView.
            if (!allow) {
              if (isIncodeSmile) {
                // If the URL is from inCodeSmile, we allow it to be opened in
                //  an in-app browser view.
                launchUrl(url, mode: LaunchMode.inAppBrowserView);
              } else {
                // The user may have completed KYC: onExit refreshes the
                // account before going back. A redirect chain leaves once.
                _leave(const KycLeftFlow());
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = navigation.resolve(request.url);
            if (url == null) return NavigationDecision.prevent;

            final isIncodeSmile = navigation.isIncode(url);
            final allow = navigation.allows(url);

            if (allow) {
              return NavigationDecision.navigate;
            } else {
              log.warning('KYC navigation blocked');
              if (isIncodeSmile) {
                launchUrl(url, mode: LaunchMode.inAppBrowserView);
              }
              return NavigationDecision.prevent;
            }
          },
          onHttpAuthRequest: (HttpAuthRequest request) {
            final auth = configuration.basicAuth;
            if (auth == null ||
                !navigation.allowsAuthentication(request.host)) {
              request.onCancel();
              return;
            }
            request.onProceed(
              WebViewCredential(user: auth.username, password: auth.password),
            );
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) async {
            // Even though the onPageFinished callback is called when the
            //  page is fully loaded, the Flutter web app inside the WebView
            //  might not have rendered correctly yet, if that happens, we should
            //  reload the WebView to ensure the Flutter app is displayed correctly.
            // This is a workaround for an issue that Flutter web apps might have,
            //  especially when they are loaded inside a WebView.
            // Checking the presence of the `flutter-view` element
            //  and its tabindex attribute is a way to determine if the Flutter
            //  web app has been rendered successfully. If the tabindex is -1,
            //  it indicates that the Flutter web app is ready and rendered.

            // Wait 10 seconds for Flutter to render and then check if the
            //  flutter-view tabindex is -1, which indicates that the
            //  Flutter web app has been rendered successfully.
            // If it is still 0, it means that the Flutter web app has not been
            //  rendered correctly, and we should reload the WebView.
            await Future.delayed(const Duration(seconds: 10));
            if (!mounted) return;

            try {
              final result = await _controller.runJavaScriptReturningResult('''
                (function() {
                  const el = document.querySelector('flutter-view');
                  return el ? el.getAttribute('tabindex') : null;
                })()
              ''');

              final isRendered = result.toString() != '0';

              if (!isRendered) {
                log.warning(
                  'Flutter view not successfully rendered. Reloading WebView.',
                );
                await _controller.reload();
              } else {}
            } catch (e) {
              log.severe(
                message: 'Error checking Flutter view readiness',
                error: e.runtimeType,
                trace: StackTrace.current,
              );
              await _controller.reload(); // fallback in case of JS failure
            }
          },
        ),
      )
      // TODO: Is this user agent necessary?
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15.0 Safari/604.1',
      )
      ..loadRequest(configuration.url);

    if (Platform.isAndroid) {
      AndroidWebViewController.enableDebugging(false);
      final platformController = _controller.platform;
      if (platformController is AndroidWebViewController) {
        platformController.setMediaPlaybackRequiresUserGesture(false);
      }
    } else if (Platform.isIOS) {
      final platformController = _controller.platform;
      if (platformController is WebKitWebViewController) {
        platformController.setAllowsBackForwardNavigationGestures(true);
      }
    }
    setState(() => _isLoadingConfiguration = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingConfiguration) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    if (_configurationFailure case final failure?) {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CloseButton(onPressed: context.pop),
            BullInfoCard(
              description: widget.host.failureMessage(context, failure),
              tagColor: context.bull.error,
              bgColor: context.bull.errorContainer,
              onTap: _retry,
            ),
          ],
        ),
      );
    }
    return SafeArea(child: WebViewWidget(controller: _controller));
  }
}
