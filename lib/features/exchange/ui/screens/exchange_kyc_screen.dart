import 'dart:io';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/material.dart';
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

    /*final isTestnet =
        context.read<SettingsCubit>().state.environment == Environment.testnet;*/
    _bbKycUrl = 'https://bbx05.bullbitcoin.dev/kyc';
    /*isTestnet
            ? ApiServiceConstants.bbKycTestUrl
            : ApiServiceConstants.bbKycUrl;*/

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) {
            final url = Uri.tryParse(change.url ?? '');
            if (url == null) return;

            final isKyc = url.path.startsWith('/kyc');
            final isLogin = url.path.contains('/login');

            final allow = isKyc || isLogin;
            log.info('UrlChange: ${url.path} → allow: $allow');

            if (!allow) {
              GoRouter.of(context).pop();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = Uri.tryParse(request.url);
            if (url == null) return NavigationDecision.prevent;

            final isKyc = url.path.startsWith('/kyc');
            final isLogin = url.path.contains('/login');
            // Downloading the bb logo triggers a request that we should allow
            //  so that the logo can be displayed while loading the KYC page.
            final isBBLogo = url.path.contains('/bb-logo');

            final allow = isKyc || isLogin || isBBLogo;
            log.info('NavigationRequest: ${url.path} → allow: $allow');

            return allow
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
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
