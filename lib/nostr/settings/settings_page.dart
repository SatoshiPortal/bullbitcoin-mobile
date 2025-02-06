import 'package:bb_mobile/_pkg/nostr/nostr.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/nostr/settings/settings_cubit.dart';
import 'package:bb_mobile/nostr/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class NostrSettingsPage extends StatelessWidget {
  const NostrSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsCubit>(
      create: (_) => SettingsCubit(),
      child: Scaffold(
        backgroundColor: Colors.amber,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: BBAppBar(
            text: 'Nostr Settings',
            onBack: () => context.pop(),
          ),
        ),
        body: BlocListener<SettingsCubit, SettingsState>(
          listener: (context, state) {
            if (state.error.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                ),
              );
              context.read<SettingsCubit>().clearError();
            }
          },
          child: BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) {
              final cubit = context.read<SettingsCubit>();

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
                        initialValue: state.secret,
                        decoration:
                            const InputDecoration(labelText: 'Your secret'),
                        onChanged: (v) => cubit.updateSecretKey(v),
                        validator: cubit.hexValidator,
                        maxLength: 64,
                      ),
                      if (state.secret.length == 64)
                        SelectableText('Pubkey: ${state.keys.public}'),
                      const SizedBox(height: 16),
                      BBButton.textWithStatusAndRightArrow(
                        label: 'Chat',
                        onPressed: () {
                          if (cubit.form.currentState!.validate()) {
                            final nostr = Nostr(
                              relay: state.relay,
                              nsec: state.secret,
                            );
                            context.push('/nostr-social', extra: nostr);
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
