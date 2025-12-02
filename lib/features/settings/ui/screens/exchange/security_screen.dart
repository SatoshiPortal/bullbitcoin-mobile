import 'dart:io';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class ExchangeSecurityScreen extends StatelessWidget {
  const ExchangeSecurityScreen({super.key});

  void _openSecurityWebView(BuildContext context) {
    final isTestnet =
        context.read<SettingsCubit>().state.environment == Environment.testnet;
    final baseUrl =
        isTestnet
            ? ApiServiceConstants.bbAuthTestUrl
            : ApiServiceConstants.bbAuthUrl;
    final securityUrl = '$baseUrl/settings';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _SecurityWebViewScreen(url: securityUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.exchangeSettingsSecuritySettingsTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BBText(
                      context.loc.exchangeSecurityManage2FAPasswordLabel,
                      style: context.font.bodyLarge?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: BBButton.big(
                        label: context.loc.exchangeSecurityAccessSettingsButton,
                        onPressed: () {
                          _openSecurityWebView(context);
                        },
                        bgColor: context.appColors.onSurface,
                        textColor: context.appColors.surface,
                        iconData: Icons.arrow_forward,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityWebViewScreen extends StatefulWidget {
  final String url;

  const _SecurityWebViewScreen({required this.url});

  @override
  State<_SecurityWebViewScreen> createState() => _SecurityWebViewScreenState();
}

class _SecurityWebViewScreenState extends State<_SecurityWebViewScreen> {
  late final WebViewController _controller = WebViewController();

  @override
  void initState() {
    super.initState();

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Allow navigation within the same domain
            if (request.url.startsWith(widget.url.split('/settings')[0])) {
              return NavigationDecision.navigate;
            }
            // Block external navigation
            return NavigationDecision.prevent;
          },
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15.0 Safari/604.1',
      )
      ..loadRequest(Uri.parse(widget.url));

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
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.exchangeSettingsSecuritySettingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }
}
