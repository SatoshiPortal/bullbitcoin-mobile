import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class RecoverWithBackupKeyScreen extends StatefulWidget {
  final bool fromOnboarding;
  const RecoverWithBackupKeyScreen({super.key, required this.fromOnboarding});

  @override
  State<RecoverWithBackupKeyScreen> createState() =>
      _RecoverWithBackupKeyScreenState();
}

class _RecoverWithBackupKeyScreenState
    extends State<RecoverWithBackupKeyScreen> {
  final _controller = TextEditingController();
  bool _justCopied = false;

  Future<void> _copyWithFeedback() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    await HapticFeedback.lightImpact();
    setState(() => _justCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justCopied = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<KeyServerCubit, KeyServerState>(
      listener: (context, state) {
        if (state.status == const KeyServerOperationStatus.success() &&
            state.backupKey.isNotEmpty) {
          _controller.text = state.backupKey;
        }
      },
      child: BlocBuilder<KeyServerCubit, KeyServerState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: context.colour.onSecondary,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              forceMaterialTransparency: true,
              flexibleSpace: TopBar(
                title: 'Enter backup key manually',
                onBack:
                    () =>
                        widget.fromOnboarding
                            ? context.pop()
                            : context.go(WalletRoute.walletHome.path),
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const Gap(20),
                    BBText(
                      'If you have exported your backup key and saved it in a seperate location by yourself, you can enter it manually here. Otherwise, go back to previous screen.',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      style: context.font.bodySmall?.copyWith(
                        color: context.colour.outline,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const Gap(40),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BBText(
                        'Enter backup key',
                        style: context.font.bodyMedium?.copyWith(
                          color: context.colour.secondary,
                        ),
                      ),
                    ),
                    const Gap(10),
                    BBInputText(
                      controller: _controller,
                      onChanged:
                          (e) => context.read<KeyServerCubit>().enterKey(e),
                      rightIcon: Icon(
                        _justCopied ? Icons.check_rounded : Icons.copy_rounded,
                        color:
                            _justCopied
                                ? context.colour.inverseSurface
                                : context.colour.onInverseSurface,
                      ),
                      onRightTap: _copyWithFeedback,
                      value: state.backupKey,
                    ),
                    const Spacer(),
                    if (widget.fromOnboarding)
                      const SizedBox.shrink()
                    else
                      GestureDetector(
                        onTap: () {
                          context.read<KeyServerCubit>().autoFetchKey();
                        },
                        child: BBText(
                          'Automatically Fetch key >>',
                          style: context.font.bodySmall?.copyWith(
                            color: context.colour.inversePrimary,
                          ),
                        ),
                      ),
                    const Gap(20),
                    BBButton.big(
                      label: 'Decrypt vault',
                      onPressed:
                          () => context
                              .read<KeyServerCubit>()
                              .updateKeyServerState(
                                secretStatus: SecretStatus.recovered,
                              ),
                      bgColor: context.colour.secondary,
                      textColor: context.colour.onSecondary,
                    ),
                    const Gap(16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
