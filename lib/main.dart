import 'dart:async';

import 'package:flutter/gestures.dart';
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
  double _zoom = 1.0;

  static const _baseWindowSize = Size(430, 390);

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;

    final direction = event.scrollDelta.dy < 0 ? 1.0 : -1.0;
    final nextZoom = (_zoom + direction * 0.1).clamp(0.6, 1.8).toDouble();
    if (nextZoom == _zoom) return;

    setState(() => _zoom = nextZoom);
    unawaited(windowManager.setSize(
      Size(_baseWindowSize.width * nextZoom, _baseWindowSize.height * nextZoom),
    ));
  }

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
    final date = '${_twoDigits(_now.day)} ${_months[_now.month - 1]}, ${_now.year}';
    final hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final period = _now.hour < 12 ? 'AM' : 'PM';
    final time = '$hour:${_twoDigits(_now.minute)} $period';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Listener(
        onPointerSignal: _handlePointerSignal,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => windowManager.startDragging(),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned(
                  top: constraints.maxHeight * 0.1,
                  left: 20 * _zoom,
                  right: 20 * _zoom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          weekday.toUpperCase(),
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'Anurati',
                            fontSize: 76 * _zoom,
                            letterSpacing: 5 * _zoom,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 4 * _zoom),
                      Text(
                        date.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18 * _zoom,
                          letterSpacing: 3 * _zoom,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 26 * _zoom),
                      Text(
                        '- $time -',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23 * _zoom,
                          fontWeight: FontWeight.bold,
                          letterSpacing: _zoom,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
