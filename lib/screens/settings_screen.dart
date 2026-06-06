import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // These hold the current settings values
  // We initialize them to the defaults and then load
  // the real values from the database in initState
  int _startHour = 9;
  int _endHour = 21;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load current settings from the database
  Future<void> _loadSettings() async {
    final db = DatabaseHelper.instance;
    final start = await db.getSettingInt('start_hour', 9);
    final end = await db.getSettingInt('end_hour', 21);
    setState(() {
      _startHour = start;
      _endHour = end;
      _isLoading = false;
    });
  }

  // Save a setting to the database whenever the user changes it
  Future<void> _saveSetting(String key, int value) async {
    final db = DatabaseHelper.instance;
    await db.setSetting(key, value.toString());
  }

  // Converts a 24-hour int like 13 into "1:00 PM"
  // We store hours as 24h internally but show 12h to the user
  String _formatHour(int hour) {
    if (hour == 0)  return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour < 12)  return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }

  // Shows a dialog letting the user pick an hour
  // This is like a popup in Python tkinter
  Future<void> _pickHour({
    required String title,
    required int currentValue,
    required int minHour,
    required int maxHour,
    required Function(int) onSelected,
  }) async {
    // showDialog returns whatever value you "pop" out of it
    // We wait for the user to pick something
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          // A scrollable list of hours to pick from
          content: SizedBox(
            width: 200,
            height: 300,
            child: ListView.builder(
              itemCount: maxHour - minHour + 1,
              itemBuilder: (context, index) {
                final hour = minHour + index;
                final isSelected = hour == currentValue;
                return ListTile(
                  title: Text(
                    _formatHour(hour),
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  // Checkmark next to the currently selected hour
                  trailing: isSelected
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    // Pop the dialog and return the selected hour
                    // Like returning a value from a function
                    Navigator.of(context).pop(hour);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    // If the user picked something (didn't cancel), save it
    if (picked != null) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [

                // ── Section header ──────────────────────────
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'PROMPT WINDOW',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // Explanation text
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Your Garmin will only ask for mood check-ins '
                    'within this time window.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),

                // ── Start hour tile ─────────────────────────
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Start Time'),
                  subtitle: const Text('First prompt of the day'),
                  // The current value shown on the right
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatHour(_startHour),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  onTap: () => _pickHour(
                    title: 'Start Time',
                    currentValue: _startHour,
                    minHour: 0,
                    // Can't start at or after end hour
                    maxHour: _endHour - 1,
                    onSelected: (hour) {
                      setState(() => _startHour = hour);
                      _saveSetting('start_hour', hour);
                    },
                  ),
                ),

                const Divider(indent: 16),

                // ── End hour tile ───────────────────────────
                ListTile(
                  leading: const Icon(Icons.nights_stay_outlined),
                  title: const Text('End Time'),
                  subtitle: const Text('Last prompt of the day'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatHour(_endHour),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  onTap: () => _pickHour(
                    title: 'End Time',
                    currentValue: _endHour,
                    // Can't end at or before start hour
                    minHour: _startHour + 1,
                    maxHour: 23,
                    onSelected: (hour) {
                      setState(() => _endHour = hour);
                      _saveSetting('end_hour', hour);
                    },
                  ),
                ),

                const Divider(indent: 16),

                // ── Summary tile ────────────────────────────
                // Read-only — just shows the current window
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.4),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, color: Colors.indigo),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Prompts will appear from '
                              '${_formatHour(_startHour)} to '
                              '${_formatHour(_endHour)} — '
                              '${_endHour - _startHour} prompts per day.',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              ],
            ),
    );
  }
}