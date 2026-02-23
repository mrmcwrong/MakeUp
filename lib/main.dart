import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:mime/mime.dart';
import 'debug_overlay.dart';
import 'debug_time.dart';

// ── Shared avatar utilities ──────────────────────────────────────────────────

/// Picks an image from [source], copies it permanently into the app's documents
/// directory, and returns the saved path. Returns null if the user cancels.
Future<String?> pickAndSaveAvatar(ImageSource source) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 512);
  if (picked == null) return null;

  final docsDir = await getApplicationDocumentsDirectory();
  final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
  final saved = await File(picked.path).copy('${docsDir.path}/$fileName');
  return saved.path;
}

/// Picks one or more files of any type and copies them into the app's
/// documents directory. Returns a list of saved paths.
Future<List<String>> pickAndSaveAttachments() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.any,
    withData: false,
    withReadStream: false,
  );
  if (result == null || result.files.isEmpty) return [];

  final docsDir = await getApplicationDocumentsDirectory();
  final saved = <String>[];

  for (final file in result.files) {
    if (file.path == null) continue;
    final fileName = 'attach_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final dest = '${docsDir.path}/$fileName';
    await File(file.path!).copy(dest);
    saved.add(dest);
  }
  return saved;
}

/// Returns true if the file at [path] is an image type.
bool isImageFile(String path) {
  final mime = lookupMimeType(path) ?? '';
  return mime.startsWith('image/');
}

/// Returns true if the file at [path] is a video type.
bool isVideoFile(String path) {
  final mime = lookupMimeType(path) ?? '';
  return mime.startsWith('video/');
}

/// Returns an appropriate icon for the file type.
IconData fileIcon(String path) {
  final mime = lookupMimeType(path) ?? '';
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime.startsWith('video/')) return Icons.videocam_outlined;
  if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
  if (mime.contains('word') || path.endsWith('.docx') || path.endsWith('.doc')) {
    return Icons.description_outlined;
  }
  if (mime.contains('sheet') || path.endsWith('.xlsx') || path.endsWith('.csv')) {
    return Icons.table_chart_outlined;
  }
  if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
  return Icons.insert_drive_file_outlined;
}

/// Displays a circular avatar — photo if a path is set, otherwise an icon.
class AvatarWidget extends StatelessWidget {
  final String? imagePath;
  final double size;
  final bool isUser;

  const AvatarWidget({
    super.key,
    required this.imagePath,
    this.size = 48,
    this.isUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imagePath != null && File(imagePath!).existsSync();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser ? AppColors.lightYellow : AppColors.warmSurface,
        border: Border.all(
          color: isUser
              ? AppColors.golden.withValues(alpha: 0.4)
              : AppColors.golden.withValues(alpha: 0.2),
          width: isUser ? 2.5 : 1.5,
        ),
        image: hasPhoto
            ? DecorationImage(image: FileImage(File(imagePath!)), fit: BoxFit.cover)
            : null,
      ),
      child: hasPhoto
          ? null
          : Icon(Icons.person, size: size * 0.5, color: AppColors.brown),
    );
  }
}

// ── Attachment widgets ───────────────────────────────────────────────────────

/// Editable attachment grid — used while composing a submission.
class AttachmentsEditor extends StatelessWidget {
  final List<String> attachments;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const AttachmentsEditor({
    super.key,
    required this.attachments,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Attachments',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.attach_file, size: 16),
              label: Text('Add File', style: GoogleFonts.dmSans(fontSize: 14)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brown,
                backgroundColor: AppColors.warmSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(attachments.length, (i) {
              final path = attachments[i];
              final name = p.basename(path);
              final isImg = isImageFile(path);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.warmSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.golden.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: isImg && File(path).existsSync()
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(File(path), fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(fileIcon(path), color: AppColors.brown, size: 28),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  name,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 9,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => onRemove(i),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// Read-only attachment grid — used when viewing past submissions.
/// Tapping a file opens it with the device's default app.
class AttachmentsViewer extends StatelessWidget {
  final List<String> attachments;

  const AttachmentsViewer({super.key, required this.attachments});

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Attachments',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: attachments.map((path) {
            final exists = File(path).existsSync();
            final name = p.basename(path);
            final isImg = isImageFile(path);
            return GestureDetector(
              onTap: () => OpenFilex.open(path),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.warmSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.golden.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: !exists
                    ? const Icon(Icons.broken_image_outlined, color: AppColors.brown)
                    : isImg
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(File(path), fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(fileIcon(path), color: AppColors.brown, size: 26),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  name,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 9,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

void main() {
  runApp(const MyApp());
}

///
/// Colors - Soft Yellow/Brown Theme (iOS Widget Inspired)
///
class AppColors {
  static const Color cream = Color(0xFFFFFDF7);
  static const Color warmSurface = Color(0xFFFFFAED);
  static const Color lightYellow = Color(0xFFFFF6E0);
  static const Color golden = Color(0xFFFFD88D);
  static const Color amber = Color(0xFFFFC247);
  static const Color brown = Color(0xFFA8907C);
  static const Color darkBrown = Color(0xFF6B5B4D);
  static const Color deepBrown = Color(0xFF4A3F35);

  static const Color success = Color(0xFF88C057);
  static const Color error = Color(0xFFE07856);
  static const Color textPrimary = Color(0xFF3D3426);
  static const Color textSecondary = Color(0xFF8B7C6B);
}

class AnimatedPoints extends StatelessWidget {
  final int points;
  final double size;

  const AnimatedPoints({super.key, required this.points, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: points),
      duration: const Duration(milliseconds: 900),
      builder: (context, value, child) {
        return Text(
          '$value',
          style: GoogleFonts.dmSans(
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: AppColors.darkBrown,
          ),
        );
      },
    );
  }
}

///
/// MODELS
///
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
  final double dailyProbability;
  DateTime? lastUpdate;

  Competitor({
    required this.name,
    this.avatarImagePath,
    required this.points,
    required this.dailyProbability,
    this.lastUpdate,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatarImagePath': avatarImagePath,
    'points': points,
    'dailyProbability': dailyProbability,
    'lastUpdate': lastUpdate?.toIso8601String(),
  };

  factory Competitor.fromJson(Map<String, dynamic> json) => Competitor(
    name: json['name'],
    avatarImagePath: json['avatarImagePath'],
    points: json['points'],
    dailyProbability: (json['dailyProbability'] as num?)?.toDouble() ?? 0.5,
    lastUpdate: json['lastUpdate'] != null
        ? DateTime.parse(json['lastUpdate'])
        : null,
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
///
class StorageService {
  static const String userKey = 'user_data';
  static const String competitorsKey = 'competitors_data';
  static const String dailyPromptsKey = 'daily_prompts_data';
  static const String weeklyTaskKey = 'weekly_task_data';

  static Future<User> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(userKey);
    if (userData == null) {
      final newUser = User();
      await saveUser(newUser);
      return newUser;
    }
    return User.fromJson(
      Map<String, dynamic>.from(jsonDecode(userData) as Map),
    );
  }

  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userKey, jsonEncode(user.toJson()));
  }

  static Future<List<Competitor>> loadCompetitors() async {
    final prefs = await SharedPreferences.getInstance();
    final competitorsData = prefs.getString(competitorsKey);
    if (competitorsData == null) {
      final competitors = _createDefaultCompetitors();
      await saveCompetitors(competitors);
      return competitors;
    }
    return List<Competitor>.from(
      (jsonDecode(competitorsData) as List).map((c) => Competitor.fromJson(c)),
    );
  }

  static Future<void> saveCompetitors(List<Competitor> competitors) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      competitorsKey,
      jsonEncode(competitors.map((c) => c.toJson()).toList()),
    );
  }

  static List<Competitor> _createDefaultCompetitors() {
    const names = [
      'Creative Spark',  'Pixel Pioneer',   'Idea Forge',      'Art Maven',
      'Design Wizard',   'Craft Master',    'Vision Seeker',   'Muse Hunter',
      'Color Alchemist', 'Form Shaper',     'Story Weaver',    'Rhythm Maker',
      'Canvas Dancer',   'Mind Sculptor',   'Dream Builder',   'Skill Crafter',
      'Pattern Finder',  'Concept Artist',  'Flow State',
    ];
    return List.generate(names.length, (i) => Competitor(
      name: names[i],
      points: 0,
      dailyProbability: (i + 1) * 0.05,
    ));
  }

  /// Catches up all missed days for every competitor and saves.
  /// Each day a competitor rolls against their dailyProbability:
  /// success → +3 points, failure → +0.
  static Future<void> updateCompetitorPoints(List<Competitor> competitors) async {
    final now = DebugTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final random = Random();
    bool anyUpdated = false;

    // Save install date on first run
    final prefs = await SharedPreferences.getInstance();
    final installDateStr = prefs.getString('install_date');
    final DateTime installDate;
    if (installDateStr == null) {
      installDate = now;
      await prefs.setString('install_date', now.toIso8601String());
    } else {
      installDate = DateTime.parse(installDateStr);
    }

    final installDay = DateTime(installDate.year, installDate.month, installDate.day);
    final isInstallDay = today == installDay;
    final isBeforeNoonOnInstallDay = isInstallDay && now.hour < 12;

    for (final competitor in competitors) {
      final DateTime lastProcessed = competitor.lastUpdate == null
          ? today.subtract(const Duration(days: 1))
          : DateTime(
              competitor.lastUpdate!.year,
              competitor.lastUpdate!.month,
              competitor.lastUpdate!.day,
            );

      if (!lastProcessed.isBefore(today)) continue;

      DateTime cursor = lastProcessed.add(const Duration(days: 1));
      while (!cursor.isAfter(today)) {
        final isTodayOnInstallDay = cursor == today && isBeforeNoonOnInstallDay;

        if (!isTodayOnInstallDay) {
          if (random.nextDouble() < competitor.dailyProbability) {
            competitor.points += 3;
          }
        }
        cursor = cursor.add(const Duration(days: 1));
      }

      competitor.lastUpdate = now;
      anyUpdated = true;
    }

    if (anyUpdated) await saveCompetitors(competitors);
  }

  static Future<DailyPromptState> loadDailyPrompts() async {
    final prefs = await SharedPreferences.getInstance();
    final promptsData = prefs.getString(dailyPromptsKey);

    if (promptsData == null) {
      final newState = _createNewDailyPrompts();
      await saveDailyPrompts(newState);
      return newState;
    }

    final state = DailyPromptState.fromJson(
      Map<String, dynamic>.from(jsonDecode(promptsData) as Map),
    );

    final now = DebugTime.now();
    final stateDate = DateTime(
      state.date.year,
      state.date.month,
      state.date.day,
    );
    final today = DateTime(now.year, now.month, now.day);

    if (stateDate.isBefore(today)) {
      final newState = _createNewDailyPrompts();
      await saveDailyPrompts(newState);
      return newState;
    }

    return state;
  }

  static Future<void> saveDailyPrompts(DailyPromptState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(dailyPromptsKey, jsonEncode(state.toJson()));
  }

  static DailyPromptState _createNewDailyPrompts() {
    final random = Random();

    final prompts = <Map<String, dynamic>>[
      _getRandomPromptFromPool(_onePointPrompts, 1, random),
      _getRandomPromptFromPool(_twoPointPrompts, 2, random),
      _getRandomPromptFromPool(_threePointPrompts, 3, random),
    ];

    return DailyPromptState(
      prompts: prompts,
      date: DebugTime.now(),
      selectedPromptIndex: null,
    );
  }

  static Map<String, dynamic> _getRandomPromptFromPool(
    List<String> pool,
    int points,
    Random random,
  ) {
    final promptText = pool[random.nextInt(pool.length)];
    return {'text': promptText, 'points': points};
  }

  static Future<WeeklyTask?> loadWeeklyTask() async {
    final prefs = await SharedPreferences.getInstance();
    final taskData = prefs.getString(weeklyTaskKey);

    if (taskData == null) {
      return null;
    }

    final task = WeeklyTask.fromJson(
      Map<String, dynamic>.from(jsonDecode(taskData) as Map),
    );

    final currentWeekKey = getWeekKey(DebugTime.now());
    if (task.weekKey != currentWeekKey) {
      return null;
    }

    return task;
  }

  static Future<void> saveWeeklyTask(WeeklyTask task) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(weeklyTaskKey, jsonEncode(task.toJson()));
  }

  static Future<void> deleteWeeklyTask() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(weeklyTaskKey);
  }

  static String getWeekKey(DateTime date) {
    final daysFromMonday = (date.weekday - 1) % 7;
    final monday = date.subtract(Duration(days: daysFromMonday));
    return '${monday.year}-${monday.month}-${monday.day}';
  }

  static final List<String> _onePointPrompts = [
    'Write a short poem about your day',
  ];

  static final List<String> _twoPointPrompts = [
    'Draw a picture in 30 minutes',
  ];

  static final List<String> _threePointPrompts = [
    'Record a demo song',
  ];
}

class DateFormat {
  static String format(DateTime date, String pattern) {
    if (pattern == 'D') {
      final firstDay = DateTime(date.year, 1, 1);
      return date.difference(firstDay).inDays.toString();
    }
    return '';
  }
}

///
/// MAIN APP
///
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<Map<String, dynamic>> _dataFuture;
  int _resetKey = 0;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final user = await StorageService.loadUser();
    final competitors = await StorageService.loadCompetitors();
    return {'user': user, 'competitors': competitors};
  }

  @override
  Widget build(BuildContext context) {
    return DebugOverlay(
      onUpdate: () {
        setState(() {
          _dataFuture = _loadData();
          _resetKey++;
        });
      },
      child: MaterialApp(
        title: 'Creativity League',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.cream,
          textTheme: GoogleFonts.dmSansTextTheme(),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.warmSurface,
            foregroundColor: AppColors.deepBrown,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.deepBrown,
              letterSpacing: -0.5,
            ),
          ),
        ),
        home: FutureBuilder<Map<String, dynamic>>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.amber,
                  ),
                ),
              );
            }
            return MainNavigationScreen(
              key: ValueKey(_resetKey),
              user: snapshot.data!['user'],
              competitors: snapshot.data!['competitors'],
            );
          },
        ),
      ),
    );
  }
}

///
/// NAVIGATION
///
class MainNavigationScreen extends StatefulWidget {
  final User user;
  final List<Competitor> competitors;

  const MainNavigationScreen({
    super.key,
    required this.user,
    required this.competitors,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late User user;
  late List<Competitor> competitors;
  Timer? _masterTimer;
  DateTime? _lastCheckedDate;
  String? _lastCheckedWeekKey;

  final GlobalKey<_HomeScreenState> _homeKey = GlobalKey<_HomeScreenState>();
  final GlobalKey<_WeeklyTaskScreenState> _weeklyKey = GlobalKey<_WeeklyTaskScreenState>();

  @override
  void initState() {
    super.initState();
    user = widget.user;
    competitors = widget.competitors;

    final now = DebugTime.now();
    _lastCheckedDate = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    _lastCheckedWeekKey = StorageService.getWeekKey(now);

    _masterTick();

    _masterTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _masterTick();
    });
  }

  @override
  void dispose() {
    _masterTimer?.cancel();
    super.dispose();
  }

  Future<void> _masterTick() async {
    final now = DebugTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final currentWeekKey = StorageService.getWeekKey(now);

    if (_lastCheckedDate == null || todayDate.isAfter(_lastCheckedDate!)) {
      await StorageService.updateCompetitorPoints(competitors);
      if (mounted) setState(() => competitors = List.from(competitors));
    }

    if (_lastCheckedDate != null && todayDate.isAfter(_lastCheckedDate!)) {
      _lastCheckedDate = todayDate;
      _homeKey.currentState?.reloadForNewDay();
    } else {
      _lastCheckedDate ??= todayDate;
    }

    if (_lastCheckedWeekKey != null && currentWeekKey != _lastCheckedWeekKey) {
      _lastCheckedWeekKey = currentWeekKey;
      _weeklyKey.currentState?.reloadForNewWeek();
    } else {
      _lastCheckedWeekKey ??= currentWeekKey;
    }
  }

  @override
  void didUpdateWidget(MainNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.competitors != widget.competitors) {
      setState(() {
        competitors = widget.competitors;
      });
    }
  }

  void _updateUser(User updatedUser) {
    setState(() {
      user = updatedUser;
    });
    StorageService.saveUser(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(key: _homeKey, user: user, onUserUpdate: _updateUser),
          WeeklyTaskScreen(key: _weeklyKey, user: user, onUserUpdate: _updateUser),
          LeagueScreen(
            user: user,
            competitors: competitors,
            onUserUpdate: _updateUser,
            onCompetitorsUpdate: (updated) {
              setState(() { competitors = updated; });
              StorageService.saveCompetitors(updated);
            },
          ),
          ProfileScreen(
            user: user,
            onUserUpdate: _updateUser,
            key: ValueKey('profile_$_currentIndex'),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.warmSurface,
        indicatorColor: AppColors.golden.withValues(alpha: 0.2),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: AppColors.brown),
            selectedIcon: Icon(Icons.home, color: AppColors.darkBrown),
            label: "Daily",
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, color: AppColors.brown),
            selectedIcon: Icon(Icons.calendar_month, color: AppColors.darkBrown),
            label: "Weekly",
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined, color: AppColors.brown),
            selectedIcon: Icon(Icons.emoji_events, color: AppColors.darkBrown),
            label: "League",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: AppColors.brown),
            selectedIcon: Icon(Icons.person, color: AppColors.darkBrown),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

///
/// HOME SCREEN (Daily Prompts)
///
class HomeScreen extends StatefulWidget {
  final User user;
  final Function(User) onUserUpdate;
  final VoidCallback? onReload;

  const HomeScreen({super.key, required this.user, required this.onUserUpdate, this.onReload});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> dailyPrompts = [];
  int? selectedPromptIndex;
  bool _isLoading = true;
  late TextEditingController _submissionController;
  Timer? _midnightTimer;
  Duration _timeUntilMidnight = Duration.zero;
  List<String> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    _submissionController = TextEditingController();
    _loadDailyPrompts();
    _updateTimeUntilMidnight();
    _midnightTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeUntilMidnight();
    });
  }

  void reloadForNewDay() {
    _loadDailyPrompts();
    setState(() => _pendingAttachments = []);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      setState(() {});
    }
  }

  String _todayKey() {
    final d = DebugTime.now();
    return "${d.year}-${d.month}-${d.day}";
  }

  bool _alreadySubmittedToday(int promptIndex) {
    return widget.user.submissions.any(
      (s) => s.promptIndex == promptIndex && s.dayKey == _todayKey(),
    );
  }

  bool _hasSubmittedAnyPromptToday() {
    return widget.user.submissions.any(
      (s) => s.dayKey == _todayKey() && s.promptIndex >= 0,
    );
  }

  Future<void> _loadDailyPrompts() async {
    final state = await StorageService.loadDailyPrompts();
    if (!mounted) return;
    setState(() {
      dailyPrompts = state.prompts;
      selectedPromptIndex = state.selectedPromptIndex;
      _submissionController.clear();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _submissionController.dispose();
    super.dispose();
  }

  void _updateTimeUntilMidnight() {
    final now = DebugTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final remaining = nextMidnight.difference(now);
    if (!mounted) return;
    setState(() {
      _timeUntilMidnight = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  String _formatCountdown(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _selectPrompt(int index) async {
    setState(() {
      selectedPromptIndex = index;
    });
    final state = DailyPromptState(
      prompts: dailyPrompts,
      date: DebugTime.now(),
      selectedPromptIndex: index,
    );
    await StorageService.saveDailyPrompts(state);
  }

  Future<void> _addAttachments() async {
    final paths = await pickAndSaveAttachments();
    if (paths.isNotEmpty) {
      setState(() => _pendingAttachments.addAll(paths));
    }
  }

  void _submitResponse(int promptIndex) {
    if (_hasSubmittedAnyPromptToday()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You already submitted today.', style: GoogleFonts.dmSans()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_submissionController.text.isEmpty && _pendingAttachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a response or attach a file', style: GoogleFonts.dmSans()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final submission = Submission(
      id: DebugTime.now().millisecondsSinceEpoch.toString(),
      text: _submissionController.text,
      points: dailyPrompts[promptIndex]['points'],
      date: DebugTime.now(),
      promptIndex: promptIndex,
      dayKey: _todayKey(),
      attachments: List.from(_pendingAttachments),
    );

    final updatedUser = User(
      username: widget.user.username,
      avatarImagePath: widget.user.avatarImagePath,
      totalPoints: widget.user.totalPoints + submission.points,
      submissions: [...widget.user.submissions, submission],
    );

    widget.onUserUpdate(updatedUser);
    _submissionController.clear();
    setState(() => _pendingAttachments = []);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Submitted! You earned ${submission.points} points',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Prompts')),
        body: Center(child: CircularProgressIndicator(color: AppColors.amber)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Prompts')),
      body: selectedPromptIndex == null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Today\'s Creative Challenge',
                    style: GoogleFonts.dmSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepBrown,
                      letterSpacing: -0.8,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pick one prompt to work on today',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: ListView.separated(
                      itemCount: dailyPrompts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        final prompt = dailyPrompts[index];
                        final isSubmitted = _alreadySubmittedToday(index);
                        return InkWell(
                          onTap: isSubmitted ? null : () => _selectPrompt(index),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isSubmitted ? AppColors.warmSurface : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSubmitted
                                    ? AppColors.golden.withValues(alpha: 0.2)
                                    : AppColors.golden.withValues(alpha: 0.4),
                                width: 2,
                              ),
                              boxShadow: isSubmitted
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: AppColors.golden.withValues(alpha: 0.1),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.golden,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${prompt['points']} points',
                                        style: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.deepBrown,
                                        ),
                                      ),
                                    ),
                                    if (isSubmitted)
                                      Icon(Icons.check_circle, color: AppColors.success, size: 24),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  prompt['text'],
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your Challenge',
                          style: GoogleFonts.dmSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepBrown,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.golden,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${dailyPrompts[selectedPromptIndex!]['points']} pts',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.deepBrown,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatCountdown(_timeUntilMidnight)} remaining',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.error,
                        ),
                      ),
                      if (!_hasSubmittedAnyPromptToday()) ...[
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            setState(() {
                              selectedPromptIndex = null;
                              _pendingAttachments = [];
                            });
                            final state = DailyPromptState(
                              prompts: dailyPrompts,
                              date: DebugTime.now(),
                              selectedPromptIndex: null,
                            );
                            await StorageService.saveDailyPrompts(state);
                          },
                          icon: Icon(Icons.refresh, size: 16, color: AppColors.brown),
                          label: Text(
                            'Change',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brown,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            backgroundColor: AppColors.warmSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.lightYellow,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.golden.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      dailyPrompts[selectedPromptIndex!]['text'],
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Your Response',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _submissionController,
                    maxLines: 8,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Share your creative work...',
                      hintStyle: GoogleFonts.dmSans(
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: AppColors.golden.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: AppColors.golden.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: AppColors.amber, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── Attachments editor ──────────────────────────────────────
                  AttachmentsEditor(
                    attachments: _pendingAttachments,
                    onAdd: _addAttachments,
                    onRemove: (i) => setState(() => _pendingAttachments.removeAt(i)),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _submitResponse(selectedPromptIndex!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Submit',
                        style: GoogleFonts.dmSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

///
/// WEEKLY TASK SCREEN
///
class WeeklyTaskScreen extends StatefulWidget {
  final User user;
  final Function(User) onUserUpdate;
  final VoidCallback? onReload;

  const WeeklyTaskScreen({
    super.key,
    required this.user,
    required this.onUserUpdate,
    this.onReload,
  });

  @override
  State<WeeklyTaskScreen> createState() => _WeeklyTaskScreenState();
}

class _WeeklyTaskScreenState extends State<WeeklyTaskScreen> {
  WeeklyTask? _weeklyTask;
  bool _isLoading = true;
  late TextEditingController _taskController;
  late TextEditingController _completionController;
  late TextEditingController _pointsController;
  Timer? _weekTimer;
  Duration _timeUntilNextWeek = Duration.zero;
  List<String> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    _taskController = TextEditingController();
    _completionController = TextEditingController();
    _pointsController = TextEditingController(text: '10');
    _loadWeeklyTask();
    _updateTimeUntilNextWeek();
    _weekTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeUntilNextWeek();
    });
  }

  @override
  void didUpdateWidget(WeeklyTaskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadWeeklyTask();
  }

  @override
  void dispose() {
    _weekTimer?.cancel();
    _taskController.dispose();
    _completionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyTask() async {
    final task = await StorageService.loadWeeklyTask();
    if (!mounted) return;
    setState(() {
      _weeklyTask = task;
      _isLoading = false;
    });
  }

  void reloadForNewWeek() {
    _loadWeeklyTask();
    setState(() => _pendingAttachments = []);
  }

  void _updateTimeUntilNextWeek() {
    final now = DebugTime.now();
    final daysUntilMonday = (8 - now.weekday) % 7;
    final nextMonday = DateTime(
      now.year,
      now.month,
      now.day + (daysUntilMonday == 0 ? 7 : daysUntilMonday),
    );
    final remaining = nextMonday.difference(now);
    if (!mounted) return;
    setState(() {
      _timeUntilNextWeek = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  String _formatCountdown(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m ${seconds}s';
    } else {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _addAttachments() async {
    final paths = await pickAndSaveAttachments();
    if (paths.isNotEmpty) {
      setState(() => _pendingAttachments.addAll(paths));
    }
  }

  Future<void> _createWeeklyTask() async {
    if (_taskController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a task description', style: GoogleFonts.dmSans()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    int points = int.tryParse(_pointsController.text) ?? 10;
    if (points < 1) points = 1;
    if (points > 15) points = 15;

    final task = WeeklyTask(
      id: DebugTime.now().millisecondsSinceEpoch.toString(),
      taskText: _taskController.text,
      points: points,
      createdDate: DebugTime.now(),
      weekKey: StorageService.getWeekKey(DebugTime.now()),
    );

    await StorageService.saveWeeklyTask(task);

    final submission = Submission(
      id: task.id,
      text: task.taskText,
      points: 0,
      date: task.createdDate,
      promptIndex: -1,
      dayKey: task.weekKey,
      attachments: const [],
    );

    final updatedUser = User(
      username: widget.user.username,
      avatarImagePath: widget.user.avatarImagePath,
      totalPoints: widget.user.totalPoints,
      submissions: [...widget.user.submissions, submission],
    );

    widget.onUserUpdate(updatedUser);

    setState(() {
      _weeklyTask = task;
      _taskController.clear();
      _pointsController.text = '10';
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Weekly task created!', style: GoogleFonts.dmSans()),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _completeWeeklyTask() async {
    if (_weeklyTask == null || _weeklyTask!.isCompleted) return;

    if (_completionController.text.isEmpty && _pendingAttachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please describe what you did or attach a file', style: GoogleFonts.dmSans()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final completedTask = _weeklyTask!.copyWith(
      completionText: _completionController.text,
      completedDate: DebugTime.now(),
    );

    await StorageService.saveWeeklyTask(completedTask);

    final completedSubmission = Submission(
      id: completedTask.id,
      text: '${completedTask.taskText}\n\nCompletion: ${_completionController.text}',
      points: completedTask.points,
      date: DebugTime.now(),
      promptIndex: -1,
      dayKey: completedTask.weekKey,
      attachments: List.from(_pendingAttachments),
    );

    final updatedSubmissions = widget.user.submissions
        .map((s) => s.id == completedTask.id ? completedSubmission : s)
        .toList();

    final updatedUser = User(
      username: widget.user.username,
      avatarImagePath: widget.user.avatarImagePath,
      totalPoints: widget.user.totalPoints + completedTask.points,
      submissions: updatedSubmissions,
    );

    widget.onUserUpdate(updatedUser);

    setState(() {
      _weeklyTask = completedTask;
      _completionController.clear();
      _pendingAttachments = [];
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Completed! You earned ${completedTask.points} points',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _deleteWeeklyTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.warmSurface,
        title: Text(
          "Delete weekly task?",
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        content: Text(
          _weeklyTask!.isCompleted
              ? "This will remove the task and deduct the points you earned."
              : "This will remove the task. You can create a new one for this week.",
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: GoogleFonts.dmSans(color: AppColors.brown)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete", style: GoogleFonts.dmSans(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final updatedSubmissions = widget.user.submissions.where((submission) {
      return !(submission.promptIndex == -1 && submission.dayKey == _weeklyTask!.weekKey);
    }).toList();

    final updatedUser = User(
      username: widget.user.username,
      avatarImagePath: widget.user.avatarImagePath,
      totalPoints: _weeklyTask!.isCompleted
          ? widget.user.totalPoints - _weeklyTask!.points
          : widget.user.totalPoints,
      submissions: updatedSubmissions,
    );

    widget.onUserUpdate(updatedUser);
    await StorageService.deleteWeeklyTask();

    setState(() {
      _weeklyTask = null;
      _pendingAttachments = [];
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Weekly task deleted", style: GoogleFonts.dmSans()),
        backgroundColor: AppColors.brown,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Weekly Challenge')),
        body: Center(child: CircularProgressIndicator(color: AppColors.amber)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Challenge')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: _weeklyTask == null ? _buildCreateTaskForm() : _buildExistingTask(),
      ),
    );
  }

  Widget _buildCreateTaskForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Your Challenge',
          style: GoogleFonts.dmSans(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.deepBrown,
            letterSpacing: -0.8,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              '${_formatCountdown(_timeUntilNextWeek)} until next week',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _taskController,
          maxLines: 4,
          style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textPrimary, height: 1.5),
          decoration: InputDecoration(
            hintText: 'What would you like to accomplish this week?',
            hintStyle: GoogleFonts.dmSans(
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              fontSize: 16,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.golden.withValues(alpha: 0.3), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.golden.withValues(alpha: 0.3), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.amber, width: 2),
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Point Value',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _pointsController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  suffixText: 'pts',
                  suffixStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.golden.withValues(alpha: 0.3), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.golden.withValues(alpha: 0.3), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.amber, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Choose between 1-15 points based on difficulty',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _createWeeklyTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: Text(
              'Create Challenge',
              style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingTask() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _weeklyTask!.isCompleted ? 'Challenge Complete' : 'Your Challenge',
          style: GoogleFonts.dmSans(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.deepBrown,
            letterSpacing: -0.8,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              '${_formatCountdown(_timeUntilNextWeek)} until next week',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _weeklyTask!.isCompleted ? AppColors.lightYellow : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _weeklyTask!.isCompleted
                  ? AppColors.golden.withValues(alpha: 0.4)
                  : AppColors.amber.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.golden,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_weeklyTask!.points} points',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.deepBrown,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: _deleteWeeklyTask,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _weeklyTask!.taskText,
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  color: AppColors.textPrimary,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_weeklyTask!.isCompleted) ...[
                const SizedBox(height: 24),
                Divider(color: AppColors.golden.withValues(alpha: 0.3)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Completed',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _weeklyTask!.completionText!,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!_weeklyTask!.isCompleted) ...[
          const SizedBox(height: 32),
          Text(
            'Mark as Complete',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _completionController,
            maxLines: 6,
            style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textPrimary, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Describe what you accomplished...',
              hintStyle: GoogleFonts.dmSans(
                color: AppColors.textSecondary.withValues(alpha: 0.4),
                fontSize: 16,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: AppColors.golden.withValues(alpha: 0.3), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: AppColors.golden.withValues(alpha: 0.3), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: AppColors.amber, width: 2),
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 24),
          // ── Attachments editor ────────────────────────────────────────────
          AttachmentsEditor(
            attachments: _pendingAttachments,
            onAdd: _addAttachments,
            onRemove: (i) => setState(() => _pendingAttachments.removeAt(i)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _completeWeeklyTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: Text(
                'Complete Challenge',
                style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

///
/// LEAGUE SCREEN
///
class LeagueScreen extends StatefulWidget {
  final User user;
  final List<Competitor> competitors;
  final Function(User) onUserUpdate;
  final Function(List<Competitor>) onCompetitorsUpdate;

  const LeagueScreen({
    super.key,
    required this.user,
    required this.competitors,
    required this.onUserUpdate,
    required this.onCompetitorsUpdate,
  });

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  late List<Map<String, dynamic>> leaderboard;

  @override
  void initState() {
    super.initState();
    _buildLeaderboard();
  }

  void _buildLeaderboard() {
    leaderboard = [
      {
        'name': widget.user.username,
        'imagePath': widget.user.avatarImagePath,
        'points': widget.user.totalPoints,
        'isUser': true,
        'competitor': null,
      },
      ...widget.competitors.map((c) => {
        'name': c.name,
        'imagePath': c.avatarImagePath,
        'points': c.points,
        'isUser': false,
        'competitor': c,
      }),
    ];
    leaderboard.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
  }

  Future<void> _showEditSheet({required bool isUser, Competitor? competitor}) async {
    final nameController = TextEditingController(
      text: isUser ? widget.user.username : competitor!.name,
    );
    String? currentImagePath = isUser ? widget.user.avatarImagePath : competitor!.avatarImagePath;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUser ? 'Edit Your Profile' : 'Edit Competitor',
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.deepBrown),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final path = await pickAndSaveAvatar(ImageSource.gallery);
                    if (path != null) setSheetState(() => currentImagePath = path);
                  },
                  child: Stack(
                    children: [
                      AvatarWidget(imagePath: currentImagePath, size: 90, isUser: true),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Name', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.golden.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.golden.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.amber, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final newName = nameController.text.trim().isEmpty
                        ? (isUser ? widget.user.username : competitor!.name)
                        : nameController.text.trim();
                    if (isUser) {
                      final updatedUser = User(
                        username: newName,
                        avatarImagePath: currentImagePath,
                        totalPoints: widget.user.totalPoints,
                        submissions: widget.user.submissions,
                      );
                      widget.onUserUpdate(updatedUser);
                    } else {
                      competitor!.name = newName;
                      competitor.avatarImagePath = currentImagePath;
                      StorageService.saveCompetitors(widget.competitors);
                      widget.onCompetitorsUpdate(widget.competitors);
                    }
                    Navigator.pop(sheetContext);
                    setState(() { _buildLeaderboard(); });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Save', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMedalColor(int rank) {
    switch (rank) {
      case 1: return AppColors.golden;
      case 2: return AppColors.brown.withValues(alpha: 0.6);
      case 3: return AppColors.brown.withValues(alpha: 0.4);
      default: return AppColors.brown;
    }
  }

  @override
  Widget build(BuildContext context) {
    _buildLeaderboard();

    return Scaffold(
      appBar: AppBar(title: const Text('League')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your League',
              style: GoogleFonts.dmSans(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.deepBrown,
                letterSpacing: -0.8,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Long-press any entry to edit name & photo',
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: ListView.separated(
                itemCount: leaderboard.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final entry = leaderboard[index];
                  final rank = index + 1;
                  final isUser = entry['isUser'] as bool;
                  final competitor = entry['competitor'] as Competitor?;

                  return GestureDetector(
                    onLongPress: () => _showEditSheet(isUser: isUser, competitor: competitor),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.lightYellow : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isUser
                              ? AppColors.golden.withValues(alpha: 0.5)
                              : AppColors.golden.withValues(alpha: 0.25),
                          width: 2,
                        ),
                        boxShadow: isUser
                            ? [
                                BoxShadow(
                                  color: AppColors.golden.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getMedalColor(rank),
                            ),
                            child: Center(
                              child: Text(
                                rank.toString(),
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          AvatarWidget(
                            imagePath: entry['imagePath'] as String?,
                            size: 44,
                            isUser: isUser,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry['name'] as String,
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: isUser ? FontWeight.w700 : FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${entry['points']}',
                            style: GoogleFonts.dmSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkBrown,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'pts',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

///
/// PROFILE SCREEN
///
class ProfileScreen extends StatefulWidget {
  final User user;
  final Function(User) onUserUpdate;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onUserUpdate,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  bool _sortNewestFirst = true;
  String _filterType = 'all';
  bool _showInProgress = true;
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showEditProfileSheet() async {
    final nameController = TextEditingController(text: widget.user.username);
    String? currentImagePath = widget.user.avatarImagePath;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Your Profile',
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.deepBrown),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final path = await pickAndSaveAvatar(ImageSource.gallery);
                    if (path != null) setSheetState(() => currentImagePath = path);
                  },
                  child: Stack(
                    children: [
                      AvatarWidget(imagePath: currentImagePath, size: 90, isUser: true),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Name', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.golden.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.golden.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.amber, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final newName = nameController.text.trim().isEmpty
                        ? widget.user.username
                        : nameController.text.trim();
                    widget.onUserUpdate(User(
                      username: newName,
                      avatarImagePath: currentImagePath,
                      totalPoints: widget.user.totalPoints,
                      submissions: widget.user.submissions,
                    ));
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Save', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.month}/${date.day}/${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _getDayOfWeek(DateTime date) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[date.weekday % 7];
  }

  List<Map<String, dynamic>> _getFilteredAndSortedItems() {
    final allItems = <Map<String, dynamic>>[];
    final searchLower = _searchQuery.toLowerCase();

    for (var submission in widget.user.submissions) {
      final isWeekly = submission.promptIndex == -1;
      final isDaily = !isWeekly;

      if (isDaily && _filterType == 'weekly') continue;
      if (isWeekly && _filterType == 'daily') continue;

      if (isWeekly && !_showInProgress &&
          !submission.text.contains('\n\nCompletion: ')) {
        continue;
      }

      if (_searchQuery.isNotEmpty &&
          !submission.text.toLowerCase().contains(searchLower)) {
        continue;
      }

      allItems.add({
        'type': isWeekly ? 'weekly' : 'daily',
        'submission': submission,
        'date': submission.date,
      });
    }

    allItems.sort((a, b) {
      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return _sortNewestFirst ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
    });

    return allItems;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final allItems = _getFilteredAndSortedItems();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showEditProfileSheet,
                      child: Stack(
                        children: [
                          AvatarWidget(imagePath: widget.user.avatarImagePath, size: 100, isUser: true),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppColors.amber,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.photo_library_outlined, size: 15, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.user.username,
                      style: GoogleFonts.dmSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepBrown,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.lightYellow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.golden.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.golden.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          widget.user.totalPoints.toString(),
                          style: GoogleFonts.dmSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkBrown,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total Points',
                          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: AppColors.golden.withValues(alpha: 0.3),
                    ),
                    Column(
                      children: [
                        Text(
                          widget.user.submissions.length.toString(),
                          style: GoogleFonts.dmSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkBrown,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Submissions',
                          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Your Activity',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepBrown,
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: GoogleFonts.dmSans(fontSize: 15, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search submissions...',
                  hintStyle: GoogleFonts.dmSans(
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.brown),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: AppColors.brown),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.golden.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.golden.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.amber, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.warmSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.golden.withValues(alpha: 0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterType,
                          icon: Icon(Icons.filter_list, color: AppColors.brown, size: 20),
                          style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textPrimary),
                          dropdownColor: AppColors.warmSurface,
                          onChanged: (String? newValue) {
                            if (newValue != null) setState(() => _filterType = newValue);
                          },
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(value: 'daily', child: Text('Daily')),
                            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _sortNewestFirst = !_sortNewestFirst),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warmSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.golden.withValues(alpha: 0.2)),
                      ),
                      child: Icon(
                        _sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                        color: AppColors.brown,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _showInProgress = !_showInProgress),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _showInProgress
                            ? AppColors.amber.withValues(alpha: 0.15)
                            : AppColors.warmSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _showInProgress
                              ? AppColors.amber.withValues(alpha: 0.4)
                              : AppColors.golden.withValues(alpha: 0.2),
                          width: _showInProgress ? 1.5 : 1,
                        ),
                      ),
                      child: Icon(
                        Icons.pending_actions,
                        color: _showInProgress ? AppColors.amber : AppColors.brown,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (allItems.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No submissions match your search.'
                          : 'No submissions yet.\nComplete a daily prompt or weekly task!',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final item = allItems[index];

                    if (item['type'] == 'weekly') {
                      final submission = item['submission'] as Submission;
                      final parts = submission.text.split('\n\nCompletion: ');
                      final taskText = parts[0];
                      final completionText = parts.length > 1 ? parts[1] : null;
                      final isCompleted = completionText != null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isCompleted ? AppColors.lightYellow : AppColors.warmSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isCompleted
                                  ? AppColors.golden.withValues(alpha: 0.3)
                                  : AppColors.amber.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.golden.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppColors.amber,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_month, size: 14, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Weekly',
                                              style: GoogleFonts.dmSans(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isCompleted) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AppColors.golden,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '+${submission.points} pts',
                                            style: GoogleFonts.dmSans(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: AppColors.deepBrown,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_getDayOfWeek(submission.date)}, ${_formatDateTime(submission.date)}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Icon(
                                      isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: isCompleted ? AppColors.success : AppColors.amber,
                                      size: 20,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      taskText,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 16,
                                        color: AppColors.textPrimary,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (isCompleted) ...[
                                const SizedBox(height: 12),
                                Divider(color: AppColors.golden.withValues(alpha: 0.3)),
                                const SizedBox(height: 8),
                                Text(
                                  'What you did:',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  completionText,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                // ── Attachments viewer ────────────────────
                                AttachmentsViewer(attachments: submission.attachments),
                              ] else ...[
                                const SizedBox(height: 8),
                                Text(
                                  'In Progress',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    color: AppColors.amber,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    } else {
                      final submission = item['submission'] as Submission;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.warmSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.golden.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.golden.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppColors.brown,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.today, size: 14, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Daily',
                                              style: GoogleFonts.dmSans(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppColors.golden,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '+${submission.points} pts',
                                          style: GoogleFonts.dmSans(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: AppColors.deepBrown,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: AppColors.warmSurface,
                                          title: Text(
                                            "Delete submission?",
                                            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                                          ),
                                          content: Text(
                                            "This will remove the submission and its points. If this is today's submission, you'll be able to resubmit.",
                                            style: GoogleFonts.dmSans(),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: Text("Cancel", style: GoogleFonts.dmSans(color: AppColors.brown)),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: Text("Delete", style: GoogleFonts.dmSans(color: AppColors.error)),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (!context.mounted) return;

                                      if (confirmed == true) {
                                        final updatedSubmissions =
                                            List<Submission>.from(widget.user.submissions)
                                              ..removeWhere((s) => s.id == submission.id);

                                        final updatedUser = User(
                                          username: widget.user.username,
                                          avatarImagePath: widget.user.avatarImagePath,
                                          totalPoints: widget.user.totalPoints - submission.points,
                                          submissions: updatedSubmissions,
                                        );

                                        widget.onUserUpdate(updatedUser);

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Submission deleted", style: GoogleFonts.dmSans()),
                                            backgroundColor: AppColors.brown,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_getDayOfWeek(submission.date)}, ${_formatDateTime(submission.date)}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                submission.text,
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                              // ── Attachments viewer ──────────────────────
                              AttachmentsViewer(attachments: submission.attachments),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}