import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(430, 390),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.setResizable(false);
    await windowManager.setHasShadow(false);
    // The native runner shows this window after its first frame. Avoid
    // windowManager.show(), which calls SetForegroundWindow on Windows.
  });

  runApp(const DayClockApp());
}

class DayClockApp extends StatelessWidget {
  const DayClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Day Clock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB4F0D0),
          surface: Colors.transparent,
        ),
      ),
      home: const ClockHomePage(),
    );
  }
}

class ClockHomePage extends StatefulWidget {
  const ClockHomePage({super.key});

  @override
  State<ClockHomePage> createState() => _ClockHomePageState();
}

class _ClockHomePageState extends State<ClockHomePage> {
  late DateTime _now;
  Timer? _timer;

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final weekday = _weekdays[_now.weekday - 1];
    final date = '${_months[_now.month - 1]} ${_now.day}, ${_now.year}';
    final time = '${_twoDigits(_now.hour)}:${_twoDigits(_now.minute)}';
    final seconds = _twoDigits(_now.second);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        child: SafeArea(
          child: Center(
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'TODAY',
                  style: TextStyle(
                    color: Color(0xFFB4F0D0),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    weekday.toUpperCase(),
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'Anurati',
                      fontSize: 76,
                      letterSpacing: 5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF9298A5),
                    fontSize: 18,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 5,
                        color: Colors.white,
                        fontFeatures: [],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      seconds,
                      style: const TextStyle(
                        color: Color(0xFFB4F0D0),
                        fontSize: 15,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB4F0D0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}
