import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A lightweight Cupertino-style bottom sheet route that covers up to 100% height.
/// This mimics the feel of a Cupertino full-screen sheet presented from the bottom.
class CupertinoSheetRoute<T> extends PageRoute<T> {
  CupertinoSheetRoute({
    required this.builder,
    this.dismissible = true,
    this.barrierTint = const Color(0x99000000),
    this.duration = const Duration(milliseconds: 350),
    RouteSettings? settings,
  }) : super(settings: settings);

  final WidgetBuilder builder;
  final bool dismissible;
  final Color barrierTint;
  final Duration duration;

  @override
  bool get barrierDismissible => dismissible;

  @override
  Color get barrierColor => barrierTint;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget page = builder(context);
    return Semantics(scopesRoute: true, explicitChildNodes: true, child: page);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.8, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}
