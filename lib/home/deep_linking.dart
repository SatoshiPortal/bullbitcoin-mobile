import 'package:bb_mobile/_pkg/deep_link.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:flutter/material.dart';

class DeepLinker extends StatefulWidget {
  const DeepLinker({super.key, required this.child});

  final Widget child;

  @override
  State<DeepLinker> createState() => _DeepLinkerState();
}

class _DeepLinkerState extends State<DeepLinker> {
  @override
  void initState() {
    if (locator.isRegistered<DeepLink>()) {
      locator<DeepLink>().initUniLink(link: linkReceived, err: errReceived);
    }
    super.initState();
  }

  @override
  void dispose() {
    if (locator.isRegistered<DeepLink>()) locator<DeepLink>().dispose();
    super.dispose();
  }

  void linkReceived(String link) async {
    final homeCubit = locator<HomeCubit>();
    final err = await locator<DeepLink>().handleUri(
      link: link,
      // settingsCubit: locator<SettingsCubit>(),
      networkCubit: locator<NetworkCubit>(),
      homeCubit: homeCubit,
      context: context,
    );

    if (err != null) homeCubit.updateErrDeepLink(err.toString());
  }

  void errReceived(String err) {
    locator<HomeCubit>().updateErrDeepLink(err);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
