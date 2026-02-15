import 'package:flutter/material.dart';

import 'src/home/home_screen.dart';
import 'src/auth/presentation/auth_screen.dart';

class AppNavigator {
  static void toHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  static void toAuth(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
      (Route<dynamic> route) => false,
    );
  }
}


