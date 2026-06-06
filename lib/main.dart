import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'models/mood_entry.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// StatefulWidget is used when the screen needs to update itself
// based on changing data — like re-rendering in Python Tkinter
// when a variable changes
class _HomeScreenState extends State<HomeScreen> {
  // This will hold the entries we read back from the database
  List<MoodEntry> _entries = [];

  // initState runs once when the screen first appears
  // like __init__ but for widgets that are on screen
  @override
  void initState() {
    super.initState();
    _runDatabaseTest();
  }

  Future<void> _runDatabaseTest() async {
    final db = DatabaseHelper.instance;

    // Insert a test entry
    await db.insertMoodEntry(MoodEntry(
      timestamp: DateTime.now(),
      moodScore: 2, // "Good"
    ));

    // Read it back
    final entries = await db.getEntriesForDay(DateTime.now());
    final average = await db.getDailyAverage(DateTime.now());

    // Print to terminal so we can see it worked
    print('Entries found: ${entries.length}');
    print('First entry: ${entries.first}');
    print('Daily average: $average');

    // Update the screen to show the entries
    // setState() tells Flutter "re-draw this widget with new data"
    // like calling update() or refresh() in other frameworks
    setState(() {
      _entries = entries;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hourly Mood'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Database test:'),
            const SizedBox(height: 16),
            // Show each entry we read from the database
            // This is like a for loop generating UI elements
            ..._entries.map((entry) => Text(
              'Score: ${entry.moodScore} at ${entry.timestamp}',
            )),
          ],
        ),
      ),
    );
  }
}