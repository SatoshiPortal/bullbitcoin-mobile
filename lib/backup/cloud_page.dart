import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/backup/bloc/cloud_cubit.dart';
import 'package:bb_mobile/backup/bloc/cloud_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CloudPage extends StatelessWidget {
  final String backupPath;
  final String backupName;

  const CloudPage({
    super.key,
    required this.backupPath,
    required this.backupName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CloudCubit>(
      create: (_) => CloudCubit(backupPath: backupPath, backupName: backupName),
      child: BlocListener<CloudCubit, CloudState>(
        listener: (context, state) {
          if (state.toast.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.toast)),
            );
            context.read<CloudCubit>().clearToast();
          }
        },
        child: BlocBuilder<CloudCubit, CloudState>(
          builder: (context, state) {
            final cubit = context.read<CloudCubit>();

            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                flexibleSpace: BBAppBar(
                  text: 'Cloud Backup',
                  onBack: () => context.pop(),
                ),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: cubit.connectAndStoreBackup,
                      child: const Text("Google Drive"),
                    ),
                    if (state.googleDriveStorage != null)
                      ElevatedButton(
                        onPressed: cubit.disconnect,
                        child: const Text("Log out"),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
