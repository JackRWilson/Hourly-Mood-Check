// A "model" is just a class that represents a piece of data.
// In Python you might use a dataclass or a dictionary for this.
// This is our MoodEntry dataclass equivalent in Dart.

class MoodEntry {
  // These are the fields every mood entry has.
  // The ? after String means it can be null (like Optional in Python)
  // id is nullable because when we first CREATE an entry, 
  // the database hasn't assigned it an id yet
  final int? id;
  final DateTime timestamp;
  final int moodScore; // -3 to +3

  // This is the constructor — like __init__ in Python
  // The curly braces mean these are "named parameters"
  // which is like def __init__(self, *, id, timestamp, mood_score) in Python
  const MoodEntry({
    this.id,
    required this.timestamp,
    required this.moodScore,
  });

  // This converts a MoodEntry into a Map (like a Python dictionary)
  // We need this to save it to SQLite, which stores data as key-value rows
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch, // SQLite stores dates as numbers
      'mood_score': moodScore,
    };
  }

  // This is a "factory constructor" — it creates a MoodEntry FROM a Map
  // We need this to read entries back out of SQLite
  // It's like a classmethod in Python: @classmethod def from_dict(cls, data)
  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      moodScore: map['mood_score'] as int,
    );
  }

  // This is like __repr__ in Python — useful for debugging
  // When you print a MoodEntry it shows something readable
  @override
  String toString() {
    return 'MoodEntry(id: $id, timestamp: $timestamp, moodScore: $moodScore)';
  }
}