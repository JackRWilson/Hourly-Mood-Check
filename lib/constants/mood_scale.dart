import 'package:flutter/material.dart';

// This is like a Python module with constants at the top level.
// We define the mood labels, scores, and colors all in one place
// so nothing is hardcoded in multiple spots.

class MoodScale {
  // A simple class to hold one mood option's data
  // Like a named tuple in Python
  static const List<MoodOption> options = [
    MoodOption(label: 'Very Good',     score:  3, color: Color(0xFF2E7D32)),
    MoodOption(label: 'Good',          score:  2, color: Color(0xFF43A047)),
    MoodOption(label: 'Slightly Good', score:  1, color: Color(0xFF8BC34A)),
    MoodOption(label: 'Neutral',       score:  0, color: Color(0xFF9E9E9E)),
    MoodOption(label: 'Slightly Bad',  score: -1, color: Color(0xFFFFB300)),
    MoodOption(label: 'Bad',           score: -2, color: Color(0xFFE64A19)),
    MoodOption(label: 'Very Bad',      score: -3, color: Color(0xFFB71C1C)),
  ];

  // Given a score like 2, returns "Good"
  // Like a dictionary lookup in Python: labels[score]
  static String labelForScore(int score) {
    return options
        .firstWhere(
          (o) => o.score == score,
          orElse: () => const MoodOption(
            label: 'Unknown', score: 0, color: Color(0xFF9E9E9E)),
        )
        .label;
  }

  // Given a score, returns its color
  static Color colorForScore(int score) {
    return options
        .firstWhere(
          (o) => o.score == score,
          orElse: () => const MoodOption(
            label: 'Unknown', score: 0, color: Color(0xFF9E9E9E)),
        )
        .color;
  }
}

// A simple data class — like a Python dataclass with frozen=True
class MoodOption {
  final String label;
  final int score;
  final Color color;

  const MoodOption({
    required this.label,
    required this.score,
    required this.color,
  });
}