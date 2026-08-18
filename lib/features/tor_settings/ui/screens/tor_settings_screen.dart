import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_proxy_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class TorSettingsScreen extends StatefulWidget {
  const TorSettingsScreen({super.key});

  @override
  State<TorSettingsScreen> createState() => _TorSettingsScreenState();
}

class _TorSettingsScreenState extends State<TorSettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TorSettingsCubit>().init();
  }

  @override
  Widget build(BuildContext context) {
    return BullPage(
      topBar: BullTopBar(
        title: context.loc.torSettingsTitle,
        onBack: context.pop,
      ),
      padding: const EdgeInsets.all(BullSpacing.md),
      scrollable: true,
      child: const Column(
        crossAxisAlignment: .stretch,
        children: [TorProxyWidget()],
      ),
    );
  }
}
