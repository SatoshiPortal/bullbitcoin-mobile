import 'dart:io';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void initState() {
    super.initState();

    final isTestnet =
        context.read<SettingsCubit>().state.environment == Environment.testnet;
    _bbKycUrl =
        isTestnet
            ? ApiServiceConstants.bbKycTestUrl
            : ApiServiceConstants.bbKycUrl;

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) {
            final url = Uri.tryParse(change.url ?? '');
            if (url == null) return;

            final isKyc = url.path.startsWith('/kyc');
            final isLogin = url.path.contains('/login');
            final isEmailVerification = url.path.contains('/verification');

            final allow = isKyc || isLogin || isEmailVerification;
            log.info('UrlChange: ${url.path} → allow: $allow');

            // Anything that is not a KYC or login URL should not be allowed and
            //  may indicate that the user is trying to leave the KYC flow, either
            //  after completing it or by trying to close the KYC flow from
            //  within the WebView.
            if (!allow) {
              // Fetch the user summary to update the exchange state before
              // going back, since the user might have completed the KYC
              // process and the exchange state needs to be updated accordingly.
              context.read<ExchangeCubit>().fetchUserSummary();
              GoRouter.of(context).pop();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = Uri.tryParse(request.url);
            if (url == null) return NavigationDecision.prevent;

            // Downloading the bb logo triggers a request that we should allow
            //  so that the logo can be displayed while loading the KYC page.
            final isBBLogo = url.path.contains('/bb-logo');
            final isLogin = url.path.contains('/login');
            final isKyc = url.path.contains('/kyc');
            final isEmailVerification = url.path.contains('/verification');

            final allow = isKyc || isLogin || isBBLogo || isEmailVerification;

            if (allow) {
              return NavigationDecision.navigate;
            } else {
              log.warning('Navigation blocked: ${url.path}');
              return NavigationDecision.prevent;
            }
          },
          onHttpAuthRequest: (HttpAuthRequest request) {
            log.info(
              'HTTP Auth request for ${request.host} with realm ${request.realm}',
            );
            request.onProceed(
              WebViewCredential(
                user: dotenv.env['BASIC_AUTH_USERNAME'] ?? '',
                password: dotenv.env['BASIC_AUTH_PASSWORD'] ?? '',
              ),
            );
          },
          onPageStarted: (String url) {
            log.info('Page started loading: $url');
          },
          onPageFinished: (String url) async {
            log.info('Page fully loaded: $url');

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
              log.info(
                'Flutter WebView ${isRendered ? 'rendered' : 'not rendered'} for url: $url with result: $result',
              );
              log.info('Flutter Web rendered based on tabindex: $isRendered');

              if (!isRendered) {
                log.warning(
                  'Flutter view not successfully rendered. Reloading WebView.',
                );
                await _controller.reload();
              } else {
                log.info('Flutter view appears to be fully rendered.');
              }
            } catch (e) {
              log.severe('Error checking Flutter view readiness: $e');
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
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: WebViewWidget(controller: _controller));
  }
}
