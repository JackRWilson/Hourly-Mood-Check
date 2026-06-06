import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const HourlyMoodApp());
}

class HourlyMoodApp extends StatelessWidget {
  const HourlyMoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hourly Mood',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}