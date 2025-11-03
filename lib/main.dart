import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap.dart';
import 'app.dart';

Future<void> main() async {
  await bootstrap(() async {
    runApp(const ProviderScope(child: App()));
  });
}
