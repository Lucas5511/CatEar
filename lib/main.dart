import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/cat_ear_app.dart';

void main() {
  runApp(const ProviderScope(child: CatEarApp()));
}
