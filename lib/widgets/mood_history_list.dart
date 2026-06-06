import 'package:flutter/material.dart';
import '../models/mood_entry.dart';
import '../constants/mood_scale.dart';

// This widget shows a list of mood entries as readable rows.
// Like "9:59 AM — Good" for each entry.
class MoodHistoryList extends StatelessWidget {
  final List<MoodEntry> entries;

  const MoodHistoryList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No mood entries yet.\nEntries will appear here after syncing from your Garmin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // ListView.builder is Flutter's efficient list widget.
    // It only builds the rows currently visible on screen —
    // like a virtual list in Python (useful for long lists).
    // shrinkWrap + NeverScrollableScrollPhysics means this list
    // sits inside a parent scroll view without conflicting with it.
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final label = MoodScale.labelForScore(entry.moodScore);
        final color = MoodScale.colorForScore(entry.moodScore);

        // Format the time as "9:59 AM"
        final hour = entry.timestamp.hour;
        final minute = entry.timestamp.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final timeString = '$displayHour:$minute $period';

        return ListTile(
          // Colored circle on the left showing mood color
          leading: CircleAvatar(
            radius: 8,
            backgroundColor: color,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          trailing: Text(
            timeString,
            style: const TextStyle(color: Colors.grey),
          ),
        );
      },
    );
  }
}