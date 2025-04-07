import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/ui/components/cards/info_card.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeErrors extends StatelessWidget {
  const HomeErrors({super.key});

  @override
  Widget build(BuildContext context) {
    final keyServerOffline = context.select(
      (HomeBloc bloc) => bloc.state.keyServerOffline,
    );
    return Padding(
      padding: const EdgeInsets.all(13.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (keyServerOffline)
            InfoCard(
              title: 'Key Server Offline',
              description: "Report the issue to support",
              tagColor: context.colour.error,
              bgColor: context.colour.onPrimary,
            ),
        ],
      ),
    );
  }
}
