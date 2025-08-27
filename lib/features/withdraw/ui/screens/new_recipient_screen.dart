import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/ui/widgets/new_recipient_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class NewRecipientScreen extends StatefulWidget {
  const NewRecipientScreen({super.key});

  @override
  State<NewRecipientScreen> createState() => _NewRecipientScreenState();
}

class _NewRecipientScreenState extends State<NewRecipientScreen> {
  late final WithdrawBloc _withdrawBloc;

  @override
  void initState() {
    super.initState();
    _withdrawBloc = context.read<WithdrawBloc>();

    _withdrawBloc.stream.listen((state) {
      log.info('🔄 Bloc state changed to: ${state.runtimeType}');
      if (state is WithdrawRecipientInputState) {
        log.info('📊 NewRecipient in state: ${state.newRecipient != null}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: 'Select recipient',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Gap(24),
                    BBText(
                      'Where and how should we send the money?',
                      style: context.font.headlineMedium?.copyWith(
                        color: context.colour.secondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(24),
                    const NewRecipientForm(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
