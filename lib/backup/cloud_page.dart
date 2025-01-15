import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/backup/bloc/cloud_cubit.dart';
import 'package:bb_mobile/backup/bloc/cloud_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:intl/intl.dart';

class CloudPage extends StatefulWidget {
  final Function(String, String)? onBackupSelected;
  const CloudPage({this.onBackupSelected});

  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  @override
  void initState() {
    final cubit = context.read<CloudCubit>();
    cubit.readAllBackups();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CloudCubit, CloudState>(
      listener: (context, state) {
        if (widget.onBackupSelected != null) {
          if (state.selectedBackup.$1.isNotEmpty &&
              state.selectedBackup.$2.isNotEmpty) {
            widget.onBackupSelected!(
              state.selectedBackup.$1,
              state.selectedBackup.$2,
            );
            context.pop();
          }
        }

        if (state.toast.isNotEmpty && state.toast != '') {
          _showSnackBar(context, state.toast, Colors.green);
          context.read<CloudCubit>().clearToast();
        }
        if (state.error.isNotEmpty && state.error != '') {
          _showSnackBar(context, state.error, Colors.red);
          context.read<CloudCubit>().clearError();
        }
      },
      builder: (context, state) {
        final cubit = context.read<CloudCubit>();
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: BBAppBar(
              text: 'Cloud Backup',
              onBack: () => context.pop(),
            ),
          ),
          body: Center(
            child: state.loading
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      const Gap(50),
                      AvailableBackups(
                        onFileSelected: (file) {
                          cubit.readCloudBackup(file);
                        },
                      ),
                      const Gap(10),
                      if (state.googleDriveStorage != null)
                        BBButton.big(
                          onPressed: cubit.disconnect,
                          label: "LOGOUT",
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
}

class AvailableBackups extends StatelessWidget {
  const AvailableBackups({super.key, required this.onFileSelected});
  final void Function(File) onFileSelected;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CloudCubit>();
    return SizedBox(
      height: 700,
      child: BlocBuilder<CloudCubit, CloudState>(
        builder: (context, state) {
          if (state.availableBackups.isEmpty) {
            return Center(
              child: Column(
                children: [
                  const Text('No backups found'),
                  const Gap(10),
                  BBButton.big(
                    onPressed: () {
                      cubit.clearToast();
                      cubit.clearError();
                      cubit.readAllBackups();
                    },
                    label: "READ ALL BACKUPS",
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            // Use ListView.separated for dividers
            itemCount: state.availableBackups.length,
            shrinkWrap: true,
            separatorBuilder: (context, index) =>
                const Divider(), // Add dividers between items
            itemBuilder: (context, index) => BackupTile(
              file: state.availableBackups[index],
              onFileSelected: onFileSelected,
            ),
          );
        },
      ),
    );
  }
}

class BackupTile extends StatelessWidget {
  const BackupTile({
    super.key,
    required this.file,
    required this.onFileSelected,
  });
  final File file;
  final void Function(File) onFileSelected; // Use void Function for clarity

  @override
  Widget build(BuildContext context) {
    final fileName = file.name?.replaceAll(".json", "");
    final parts = fileName?.split('_');
    final backupId = parts?.last;
    final dateTimeString = parts?.first;
    final dateTime =
        DateTime.fromMillisecondsSinceEpoch(int.parse(dateTimeString!));

    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    return ListTile(
      onTap: () => onFileSelected(file),
      title: BBText.body(
        backupId ?? 'Unnamed File',
        isBold: true,
      ),
      subtitle: BBText.bodySmall(
        formattedDate,
      ),
    );
  }
}
