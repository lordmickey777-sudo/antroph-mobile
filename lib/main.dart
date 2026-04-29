import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap.dart';
import 'app.dart';
import 'widgets/restart_widget.dart';

Future<void> main() async {
  await bootstrap(() async {
    runApp(
      const RestartWidget(
        child: App(),
      ),
    );
  });
}
