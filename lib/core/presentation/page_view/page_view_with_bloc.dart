import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PageViewWithBloc extends StatefulWidget {
  final List<Widget> pages;
  final ScrollPhysics? physics;

  const PageViewWithBloc({super.key, required this.pages, this.physics});

  @override
  State<PageViewWithBloc> createState() => _PageViewWithBlocState();
}

class _PageViewWithBlocState extends State<PageViewWithBloc> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PageViewBloc(totalPages: widget.pages.length),
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
            children: widget.pages,
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
