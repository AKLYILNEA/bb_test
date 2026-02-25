import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef OnSelected = void Function(int index);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeBackScope(
      child: Material(
        color: context.colorScheme.surface,
        child: Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(navigationStateProvider);
            final isMobile = state.viewMode == ViewMode.mobile;
            final navigationItems = state.navigationItems;
            final currentIndex = state.currentIndex;
            final bottomNavigationBar = GoogleBottomNavBar(
              navigationItems: navigationItems,
              selectedIndex: currentIndex,
              onTabChange: (index) {
                globalState.appController.toPage(navigationItems[index].label);
              },
            );
            if (isMobile) {
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: globalState.appState.systemUiOverlayStyle.copyWith(
                  systemNavigationBarColor:
                      context.colorScheme.surfaceContainer,
                ),
                child: Column(
                  children: [
                    Flexible(
                      flex: 1,
                      child: MediaQuery.removePadding(
                        removeTop: false,
                        removeBottom: true,
                        removeLeft: true,
                        removeRight: true,
                        context: context,
                        child: child!,
                      ),
                    ),
                    MediaQuery.removePadding(
                      removeTop: true,
                      removeBottom: false,
                      removeLeft: true,
                      removeRight: true,
                      context: context,
                      child: bottomNavigationBar,
                    ),
                  ],
                ),
              );
            } else {
              return child!;
            }
          },
          child: Consumer(
            builder: (_, ref, _) {
              final navigationItems = ref
                  .watch(currentNavigationItemsStateProvider)
                  .value;
              final isMobile = ref.watch(isMobileViewProvider);
              return _HomePageView(
                navigationItems: navigationItems,
                pageBuilder: (_, index) {
                  final navigationItem = navigationItems[index];
                  final navigationView = navigationItem.builder(context);
                  return KeepScope(
                    key: ValueKey(navigationItem.label),
                    keep: navigationItem.keep,
                    child: isMobile
                        ? navigationView
                        : Navigator(
                            pages: [MaterialPage(child: navigationView)],
                            onDidRemovePage: (_) {},
                          ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;
  late final ProviderSubscription<PageLabel> _pageLabelSubscription;

  @override
  initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    _pageLabelSubscription = ref.listenManual(currentPageLabelProvider, (
      prev,
      next,
    ) {
      if (prev != next) {
        _toPage(next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length) {
      _updatePageController();
    }
  }

  int get _pageIndex {
    return widget.navigationItems.indexWhere(
      (item) => item.label == globalState.appState.pageLabel,
    );
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      return;
    }
    final isAnimateToPage = ref.read(appSettingProvider).isAnimateToPage;
    final isMobile = ref.read(isMobileViewProvider);
    if (isAnimateToPage && isMobile && !ignoreAnimateTo) {
      await _pageController.animateToPage(
        index,
        duration: kTabScrollDuration,
        curve: Curves.easeOut,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  void _updatePageController() {
    final pageLabel = ref.read(currentPageLabelProvider);
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageLabelSubscription.close();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.navigationItems.length,
      itemBuilder: (context, index) {
        return widget.pageBuilder(context, index);
      },
    );
  }
}

class HomeBackScope extends ConsumerStatefulWidget {
  final Widget child;

  const HomeBackScope({super.key, required this.child});

  @override
  ConsumerState<HomeBackScope> createState() => _HomeBackScopeState();
}

class _HomeBackScopeState extends ConsumerState<HomeBackScope> {
  int? sdkInt;

  @override
  void initState() {
    super.initState();
    if (system.isAndroid) {
      system.version.then((value) {
        if (mounted) {
          setState(() {
            sdkInt = value;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (system.isAndroid) {
      if (sdkInt == null) {
        return widget.child;
      }

      if (sdkInt! < 31) {
        return CommonPopScope(
          onPop: () async {
            final canPop = Navigator.canPop(context);
            if (canPop) {
              Navigator.pop(context);
            } else {
              await globalState.appController.handleBackOrExit();
            }
            return false;
          },
          child: widget.child,
        );
      }

      final backBlock = ref.watch(backBlockProvider);
      return PopScope(
        canPop: !backBlock,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
        },
        child: widget.child,
      );
    }
    return widget.child;
  }
}
