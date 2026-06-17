import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/mood_entry.dart';
import '../widgets/mood_chart.dart';
import '../widgets/mood_history_list.dart';
import 'settings_screen.dart';
import '../constants/mood_scale.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // The day currently being viewed
  DateTime _selectedDay = DateTime.now();

  // The mood entries for that day
  List<MoodEntry> _entries = [];

  // The average mood score for that day (null if no entries)
  double? _average;

  // Whether we're currently loading data
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Loads entries from the database for the selected day
  Future<void> _loadData() async {
    // Tell Flutter we're loading so the UI can show a spinner
    setState(() => _isLoading = true);

    final db = DatabaseHelper.instance;
    final entries = await db.getEntriesForDay(_selectedDay);
    final average = await db.getDailyAverage(_selectedDay);

    // Tell Flutter we're done loading and update the data
    setState(() {
      _entries = entries;
      _average = average;
      _isLoading = false;
    });
  }

  // Go back one day
  void _previousDay() {
    setState(() {
      _selectedDay = _selectedDay.subtract(const Duration(days: 1));
    });
    _loadData();
  }

  // Go forward one day (but not past today)
  void _nextDay() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_selectedDay.isBefore(tomorrow)) {
      setState(() {
        _selectedDay = _selectedDay.add(const Duration(days: 1));
      });
      _loadData();
    }
  }

  // Formats the selected day for the header
  // e.g. "Today", "Yesterday", or "Mon, Jun 3"
  String _formatDay(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(day.year, day.month, day.day);

    if (selected == today) return 'Today';
    if (selected == today.subtract(const Duration(days: 1))) return 'Yesterday';

    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final weekday = days[day.weekday - 1];
    final month = months[day.month - 1];
    return '$weekday, $month ${day.day}';
  }

  // Formats the average score as a readable string
  String _formatAverage(double? avg) {
    if (avg == null) return 'No data';
    // Round to nearest integer and get the label
    final rounded = avg.round();
    // Show the number and the label
    return '${avg.toStringAsFixed(1)} — ${_averageLabel(avg)}';
  }

  String _averageLabel(double avg) {
    if (avg >= 2.5)  return 'Very Good';
    if (avg >= 1.5)  return 'Good';
    if (avg >= 0.5)  return 'Slightly Good';
    if (avg >= -0.5) return 'Neutral';
    if (avg >= -1.5) return 'Slightly Bad';
    if (avg >= -2.5) return 'Bad';
    return 'Very Bad';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Hourly Mood'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            // Navigator.push slides to a new screen
            // Like opening a new window in Python tkinter
            // When the user presses back, it slides back here
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      // SingleChildScrollView makes the whole screen scrollable
      // so it works even on small screens
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Day picker row ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left arrow button
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousDay,
                  ),
                  // Day label in the middle
                  Text(
                    _formatDay(_selectedDay),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Right arrow button — greyed out if viewing today
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _selectedDay.day == DateTime.now().day
                        ? null   // null disables the button
                        : _nextDay,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Average mood card ───────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.bar_chart, color: Colors.indigo),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Daily Average',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          Text(
                            _formatAverage(_average),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Chart ───────────────────────────────────────
              const Text('Mood Over Time',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey)),
              const SizedBox(height: 8),

              // Show a loading spinner while data loads,
              // otherwise show the chart
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : MoodChart(entries: _entries),

              const SizedBox(height: 24),

              // ── History list ────────────────────────────────
              const Text('Entry History',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey)),
              const SizedBox(height: 8),

              _isLoading
                  ? const SizedBox()
                  : MoodHistoryList(entries: _entries),

            ],
          ),
        ),
      ),

      // ── FAB for adding test entries ──────────────────────────
      // Floating Action Button — the + button in the bottom right.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMoodPicker,
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
    );
  }

  // Shows a bottom sheet (panel that slides up from the bottom)
  // letting the user manually add a mood entry.
  // This simulates what Garmin sync will do automatically later.
  Future<void> _showMoodPicker() async {
    await showModalBottomSheet(
      context: context,
      // Makes the sheet taller than the default
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar at the top — standard bottom sheet UI convention
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'How have you been feeling\nthis last hour?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Show current time so it's clear what time this entry is for
              Text(
                _formatCurrentTime(),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // One button for each mood option
              // Like a for loop generating UI elements
              ...MoodScale.options.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity, // Full width button
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: option.color,
                        side: BorderSide(color: option.color),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        // Close the bottom sheet first
                        Navigator.pop(context);
                        // Save the entry to the database
                        await _saveMoodEntry(option.score);
                      },
                      child: Text(
                        option.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // Saves a mood entry with the current timestamp
  // This is what Garmin sync will call automatically in the future —
  // the database code stays exactly the same, we just call it
  // from the sync handler instead of from this manual picker
  Future<void> _saveMoodEntry(int score) async {
    final db = DatabaseHelper.instance;
    await db.insertMoodEntry(MoodEntry(
      timestamp: DateTime.now(),
      moodScore: score,
    ));
    // Reload the chart and history list with the new entry
    await _loadData();
  }

  // Formats the current time as "9:59 AM"
  String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}