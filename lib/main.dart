import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'views/game_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const VoidShiftApp());
}

class VoidShiftApp extends StatelessWidget {
  const VoidShiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VOID SHIFT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050010),
        fontFamily: 'monospace',
      ),
      home: const Scaffold(
        backgroundColor: Color(0xFF050010),
        body: SafeArea(child: GameView()),
      ),
    );
  }
}
