import 'dart:async';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/widgets/view_vault_key_warning_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_privacy/screen_privacy.dart';

class ViewVaultKeyPage extends StatefulWidget {
  final String vaultKey;

  const ViewVaultKeyPage({super.key, required this.vaultKey});

  /// Consume the verified key from the flow; the reveal screen owns its
  /// remaining lifetime, not the flow's observable state.
  static Future<void> showVerified(BuildContext context) async {
    final bloc = context.read<RecoverBullBloc>();
    final key = bloc.state.vaultKey;
    if (key == null) return;
    bloc.add(const OnVaultKeyCleared());
    final router = GoRouter.of(context);
    final confirmed = await ViewVaultKeyWarningBottomSheet.show(context);
    if (!context.mounted) return;
    if (confirmed == true) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ViewVaultKeyPage(vaultKey: key)),
      );
    }
    if (context.mounted) router.pop();
  }

  @override
  State<ViewVaultKeyPage> createState() => _ViewVaultKeyPageState();
}

class _ViewVaultKeyPageState extends State<ViewVaultKeyPage>
    with PrivacyScreen, WidgetsBindingObserver {
  late final Future<void> _privacy;
  bool _active = true;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _privacy = _protect();
  }

  Future<void> _protect() async {
    if (!ScreenCaptureProtection.instance.enabledByUser) {
      throw const ScreenCaptureProtectionException();
    }
    await enableScreenPrivacy();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _active = state == AppLifecycleState.resumed);
    if (!_leaving &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      _leaving = true;
      final route = ModalRoute.of(context);
      final navigator = Navigator.of(context);
      // Dismiss any value-reveal modal as well as this page. A resumed route
      // must never expose a key retained before backgrounding.
      navigator.popUntil((candidate) => identical(candidate, route));
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaultKey = _active && !_leaving ? widget.vaultKey : '';
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.recoverbullVaultKey)),
      body: FutureBuilder<void>(
        future: _privacy,
        builder: (context, snapshot) => snapshot.hasError
            ? const PrivacyUnavailableNotice(standalone: false)
            : snapshot.connectionState != ConnectionState.done
            ? const Center(child: FadingLinearProgress(trigger: true))
            : SafeArea(
                child: Column(
                  mainAxisAlignment: .center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: CopyInput(
                        sensitive: true,
                        text: vaultKey.length >= 6
                            ? vaultKey.substring(0, 6) +
                                  '*' * (vaultKey.length - 6)
                            : '',
                        canShowValueModal: true,
                        maxLines: 1,

                        clipboardText: vaultKey,
                        overflow: .clip,
                        modalContent: vaultKey
                            .replaceAllMapped(
                              RegExp('.{1,4}'),
                              (match) => '${match.group(0)} ',
                            )
                            .trim(),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
