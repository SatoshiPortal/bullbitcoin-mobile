import 'package:bb_mobile/features/exchange/ui/exchange_kyc_navigation.dart';

import 'dart:async';
import 'dart:io';

import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_web_settings_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_failure_banner.dart';
import 'package:bb_mobile/locator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class ExchangeKycScreen extends StatefulWidget {
  const ExchangeKycScreen({super.key});

  @override
  State<ExchangeKycScreen> createState() => _ExchangeKycScreenState();
}

class _ExchangeKycScreenState extends State<ExchangeKycScreen> {
  late final WebViewController _controller = WebViewController();
  late final String _bbKycUrl;
  String? _basicAuthUsername;
  String? _basicAuthPassword;

  bool _isLoadingConfiguration = true;
  ExchangeFailure? _configurationFailure;

  @override
  void initState() {
    super.initState();

    unawaited(_load());
  }

  Future<void> _retry() async {
    setState(() {
      _isLoadingConfiguration = true;
      _configurationFailure = null;
    });
    await _load();
  }

  Future<void> _load() async {
    final result = await locator<GetExchangeWebSettingsUsecase>().execute();
    if (!mounted) return;
    final ExchangeWebPreferences settingsState;
    switch (result) {
      case Ok(:final value):
        settingsState = value;
      case Err(:final failure):
        setState(() {
          _isLoadingConfiguration = false;
          _configurationFailure = failure;
        });
        return;
    }
    final isTestnet = settingsState.environment == Environment.testnet;
    _bbKycUrl = isTestnet
        ? ApiServiceConstants.bbKycTestUrl
        : ApiServiceConstants.bbKycUrl;
    if (isTestnet) {
      _basicAuthUsername = settingsState.exchangeTestnetBasicAuthUsername;
      _basicAuthPassword = settingsState.exchangeTestnetBasicAuthPassword;
    }

    final navigation = ExchangeKycNavigation(_bbKycUrl);
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) {
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
                // Fetch the user summary to update the exchange state before
                // going back, since the user might have completed the KYC
                // process and the exchange state needs to be updated accordingly.
                context.read<ExchangeCubit>().fetchUserSummary();
                GoRouter.of(context).pop();
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
            final username = _basicAuthUsername;
            final password = _basicAuthPassword;
            if (username == null ||
                password == null ||
                !navigation.allowsAuthentication(request.host)) {
              request.onCancel();
              return;
            }
            request.onProceed(
              WebViewCredential(user: username, password: password),
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
                error: e,
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
      ..loadRequest(Uri.parse(_bbKycUrl));

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
            ExchangeFailureBanner(failure: failure, onRetry: _retry),
          ],
        ),
      );
    }
    return SafeArea(child: WebViewWidget(controller: _controller));
  }
}
