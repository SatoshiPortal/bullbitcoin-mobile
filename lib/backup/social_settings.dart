import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/backup/bloc/social_setting_state.dart';
import 'package:bb_mobile/backup/bloc/social_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SocialSettingsPage extends StatefulWidget {
  const SocialSettingsPage({super.key});

  @override
  _SocialSettingsPageState createState() => _SocialSettingsPageState();
}

class _SocialSettingsPageState extends State<SocialSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<SocialSettingsCubit>(
      create: (_) => SocialSettingsCubit()..init(),
      child: Scaffold(
        backgroundColor: Colors.amber,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: BBAppBar(
            text: 'Social',
            onBack: () => context.pop(),
          ),
        ),
        body: BlocListener<SocialSettingsCubit, SocialSettingState>(
          listener: (context, state) {
            if (state.error.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                ),
              );
              context.read<SocialSettingsCubit>().clearError();
            }
          },
          child: BlocBuilder<SocialSettingsCubit, SocialSettingState>(
            builder: (context, state) {
              final cubit = context.read<SocialSettingsCubit>();

              return Form(
                key: cubit.form,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        initialValue: state.relay,
                        decoration: const InputDecoration(labelText: 'Relay'),
                        onChanged: (v) => cubit.updateRelay(v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: state.secretKey,
                        decoration:
                            const InputDecoration(labelText: 'Your secret'),
                        onChanged: (v) => cubit.updateSecretKey(v),
                        validator: cubit.hexValidator,
                        maxLength: 64,
                      ),
                      SelectableText('Pubkey: ${state.publicKey}'),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: state.receiverPublicKey,
                        decoration:
                            const InputDecoration(labelText: 'Friend public'),
                        onChanged: (v) => cubit.updateReceiverPublicKey(v),
                        validator: cubit.hexValidator,
                        maxLength: 64,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: state.backupKey,
                        decoration:
                            const InputDecoration(labelText: 'Backup Key'),
                        onChanged: (v) => cubit.updateBackupKey(v),
                        validator: cubit.hexValidator,
                        maxLength: 64,
                      ),
                      const SizedBox(height: 16),
                      BBButton.textWithStatusAndRightArrow(
                        label: 'Chat with friend',
                        onPressed: () {
                          if (cubit.form.currentState!.validate()) {
                            context.push('/social', extra: state);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
