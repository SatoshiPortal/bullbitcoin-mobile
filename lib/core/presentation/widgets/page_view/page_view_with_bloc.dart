import 'package:bb_mobile/core/presentation/widgets/page_view/bloc/page_view_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PageViewWithBloc extends StatefulWidget {
  final List<Widget Function(BuildContext, PageViewBloc)> pageBuilders;
  final ScrollPhysics? physics;

  const PageViewWithBloc({super.key, required this.pageBuilders, this.physics});

  @override
  State<PageViewWithBloc> createState() => _PageViewWithBlocState();
}

class _PageViewWithBlocState extends State<PageViewWithBloc> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PageViewBloc(totalPages: widget.pageBuilders.length),
      child: BlocBuilder<PageViewBloc, PageViewState>(
        builder: (context, state) {
          // Sync the PageController with the BLoC state
          // Delay syncing until after the first frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients &&
                state.currentPage != _pageController.page?.round()) {
              _pageController.jumpToPage(state.currentPage);
            }
          });

          return PageView(
            controller: _pageController,
            physics: widget.physics,
            children: widget.pageBuilders
                .map(
                  (pageBuilder) =>
                      pageBuilder(context, context.read<PageViewBloc>()),
                )
                .toList(),
            onPageChanged: (index) {
              // Update BLoC when the user navigates through the PageView
              context.read<PageViewBloc>().add(PageViewPageChanged(index));
            },
          );
        },
      ),
    );
  }
}
