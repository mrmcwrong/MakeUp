part of '../main.dart';

class Submission {
  final String id;
  final String text;
  final int points;
  final DateTime date;
  final int promptIndex;
  final String dayKey;
  final List<String> attachments;

  Submission({
    required this.id,
    required this.text,
    required this.points,
    required this.date,
    required this.promptIndex,
    required this.dayKey,
    this.attachments = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'points': points,
    'date': date.toIso8601String(),
    'promptIndex': promptIndex,
    'dayKey': dayKey,
    'attachments': attachments,
  };

  factory Submission.fromJson(Map<String, dynamic> json) => Submission(
    id: json['id'],
    text: json['text'],
    points: json['points'],
    date: DateTime.parse(json['date']),
    promptIndex: json['promptIndex'],
    dayKey: json['dayKey'],
    attachments: List<String>.from(json['attachments'] ?? []),
  );
}

class WeeklyTask {
  final String id;
  final String taskText;
  final int points;
  final DateTime createdDate;
  final String? completionText;
  final DateTime? completedDate;
  final String weekKey;

  WeeklyTask({
    required this.id,
    required this.taskText,
    this.points = 10,
    required this.createdDate,
    this.completionText,
    this.completedDate,
    required this.weekKey,
  });

  bool get isCompleted => completionText != null && completedDate != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskText': taskText,
    'points': points,
    'createdDate': createdDate.toIso8601String(),
    'completionText': completionText,
    'completedDate': completedDate?.toIso8601String(),
    'weekKey': weekKey,
  };

  factory WeeklyTask.fromJson(Map<String, dynamic> json) => WeeklyTask(
    id: json['id'],
    taskText: json['taskText'],
    points: json['points'],
    createdDate: DateTime.parse(json['createdDate']),
    completionText: json['completionText'],
    completedDate: json['completedDate'] != null
        ? DateTime.parse(json['completedDate'])
        : null,
    weekKey: json['weekKey'],
  );

  WeeklyTask copyWith({
    String? id,
    String? taskText,
    int? points,
    DateTime? createdDate,
    String? completionText,
    DateTime? completedDate,
    String? weekKey,
  }) {
    return WeeklyTask(
      id: id ?? this.id,
      taskText: taskText ?? this.taskText,
      points: points ?? this.points,
      createdDate: createdDate ?? this.createdDate,
      completionText: completionText ?? this.completionText,
      completedDate: completedDate ?? this.completedDate,
      weekKey: weekKey ?? this.weekKey,
    );
  }
}

class Competitor {
  String name;
  String? avatarImagePath;
  int points;

  /// Probability (0.0 to 1.0) that this competitor receives daily points.
  /// Mutable so users can adjust in the UI in future updates.
  double dailyProbability;

  /// Probability (0.0 to 1.0) that this competitor receives weekly points.
  /// Mutable so users can adjust in the UI in future updates.
  double weeklyProbability;

  // lastProcessedDay: the last day (date only, no time) we have already
  // awarded points for. null = league not started or never ticked yet.
  DateTime? lastProcessedDay;

  Competitor({
    required this.name,
    this.avatarImagePath,
    required this.points,
    required this.dailyProbability,
    this.weeklyProbability = 1.0,
    this.lastProcessedDay,
  });

  /// Check if daily points should be awarded based on probability.
  bool shouldAwardDailyPoints() {
    return Random().nextDouble() < dailyProbability;
  }

  /// Check if weekly points should be awarded based on probability.
  bool shouldAwardWeeklyPoints() {
    return Random().nextDouble() < weeklyProbability;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatarImagePath': avatarImagePath,
    'points': points,
    'dailyProbability': dailyProbability,
    'weeklyProbability': weeklyProbability,
    'lastProcessedDay': lastProcessedDay?.toIso8601String(),
  };

  factory Competitor.fromJson(Map<String, dynamic> json) => Competitor(
    name: json['name'],
    avatarImagePath: json['avatarImagePath'],
    points: json['points'],
    dailyProbability: (json['dailyProbability'] as num?)?.toDouble() ?? 0.5,
    weeklyProbability:
        (json['weeklyProbability'] as num?)?.toDouble() ??
        ((json['dailyProbability'] as num?)?.toDouble() ?? 0.5),
    lastProcessedDay: json['lastProcessedDay'] != null
        ? DateTime.parse(json['lastProcessedDay'])
        : (json['lastUpdate'] !=
                  null // migrate old field name
              ? DateTime.parse(json['lastUpdate'])
              : null),
  );
}

class User {
  String username;
  String? avatarImagePath;
  int totalPoints;
  List<Submission> submissions;

  User({
    this.username = 'Creative User',
    this.avatarImagePath,
    this.totalPoints = 0,
    this.submissions = const [],
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'avatarImagePath': avatarImagePath,
    'totalPoints': totalPoints,
    'submissions': submissions.map((s) => s.toJson()).toList(),
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    username: json['username'],
    avatarImagePath: json['avatarImagePath'],
    totalPoints: json['totalPoints'],
    submissions: List<Submission>.from(
      (json['submissions'] as List).map((s) => Submission.fromJson(s)),
    ),
  );
}

class DailyPromptState {
  final List<Map<String, dynamic>> prompts;
  final DateTime date;
  final int? selectedPromptIndex;

  DailyPromptState({
    required this.prompts,
    required this.date,
    this.selectedPromptIndex,
  });

  Map<String, dynamic> toJson() => {
    'prompts': prompts,
    'date': date.toIso8601String(),
    'selectedPromptIndex': selectedPromptIndex,
  };

  factory DailyPromptState.fromJson(Map<String, dynamic> json) =>
      DailyPromptState(
        prompts: List<Map<String, dynamic>>.from(json['prompts']),
        date: DateTime.parse(json['date']),
        selectedPromptIndex: json['selectedPromptIndex'],
      );
}

///
/// STORAGE
