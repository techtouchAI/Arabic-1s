import 'package:flutter/material.dart';

import 'app.dart';
import 'presentation/state/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppBootstrap.initialize();
  runApp(BayanApp(state: state));
}
