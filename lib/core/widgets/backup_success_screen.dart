import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BackupSuccessScreen extends StatelessWidget {
  const BackupSuccessScreen({
    super.key,
    required this.title,
    required this.message,
    required this.buttonLabel,
  });

  final String title;
  final String message;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) => BullBackupSuccessScreen(
    title: title,
    message: message,
    buttonLabel: buttonLabel,
    onTap: () {
      context.read<WalletBloc>().add(const VerifyBackupStatus());
      context.goNamed(WalletRoute.walletHome.name);
    },
  );
}
