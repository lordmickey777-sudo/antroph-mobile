import 'package:flutter/widgets.dart';

/// Global observer used to notify widgets about route transitions.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
