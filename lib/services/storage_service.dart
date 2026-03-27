part of '../main.dart';

class StorageService {
  static const String userKey = 'user_data';
  static const String competitorsKey = 'competitors_data';
  static const String dailyPromptsKey = 'daily_prompts_data';
  static const String weeklyTaskKey = 'weekly_task_data';
  static const String leagueStartKey = 'league_start_date';
  static const String confirmLeagueStartKey = 'confirm_league_start';
  static const String dynamicLeagueDifficultyKey = 'dynamic_league_difficulty';
  static const String leagueDifficultyPresetKey = 'league_difficulty_preset';
  static const String showIndividualProbabilitySelectorsKey =
      'show_individual_probability_selectors';
  static const String displayThemeKey = 'display_theme';
  static const String fontScaleKey = 'font_scale';
  static const String dailyPromptRefreshDayKey = 'daily_prompt_refresh_day';
  static const String dailyPromptCategorySettingsKey =
      'daily_prompt_category_settings';
  static const String promptDatasetAssetPath = 'assets/prompts/all_prompts.json';
  static const List<String> promptCategories = [
    'Music Creation',
    'Poetry',
    'Painting',
    'Sculpting',
    'Academic Papers',
    'Screenwriting',
    'Photography',
    'Game Design',
    'Dance Choreography',
    'Theater',
    'Product Design',
    'Architecture',
  ];
  static List<Map<String, dynamic>>? _promptDatasetCache;
  static const List<String> _defaultCompetitorAvatarAssets = [
    'assets/avatars/competitor_01.png',
    'assets/avatars/competitor_02.png',
    'assets/avatars/competitor_03.png',
    'assets/avatars/competitor_04.png',
    'assets/avatars/competitor_05.png',
    'assets/avatars/competitor_06.png',
  ];

  static Future<DateTime?> loadLeagueStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(leagueStartKey);
    return val != null ? DateTime.parse(val) : null;
  }

  static Future<void> saveLeagueStartDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(leagueStartKey, date.toIso8601String());
  }

  static Future<void> clearLeagueStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(leagueStartKey);
  }

  static Future<bool> loadConfirmLeagueStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(confirmLeagueStartKey) ?? true;
  }

  static Future<void> saveConfirmLeagueStart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(confirmLeagueStartKey, value);
  }

  static Future<bool> loadDynamicLeagueDifficulty() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(dynamicLeagueDifficultyKey) ?? true;
  }

  static Future<void> saveDynamicLeagueDifficulty(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(dynamicLeagueDifficultyKey, value);
  }

  static Future<String> loadLeagueDifficultyPreset() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(leagueDifficultyPresetKey) ?? 'medium';
    if (value == 'easy' ||
        value == 'medium' ||
        value == 'hard' ||
        value == 'custom') {
      return value;
    }
    return 'medium';
  }

  static Future<void> saveLeagueDifficultyPreset(String preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(leagueDifficultyPresetKey, preset);
  }

  static Future<bool> loadShowIndividualProbabilitySelectors() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(showIndividualProbabilitySelectorsKey) ?? true;
  }

  static Future<void> saveShowIndividualProbabilitySelectors(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(showIndividualProbabilitySelectorsKey, value);
  }

  static bool applyLeagueDifficultyPreset(
    List<Competitor> competitors,
    String preset,
  ) {
    double minProbability;
    double maxProbability;

    switch (preset) {
      case 'easy':
        minProbability = 0.05;
        maxProbability = 0.35;
        break;
      case 'hard':
        minProbability = 0.50;
        maxProbability = 0.95;
        break;
      case 'medium':
      default:
        minProbability = 0.30;
        maxProbability = 0.80;
        break;
    }

    final ladder = _buildProbabilityLadder(
      competitors.length,
      minProbability: minProbability,
      maxProbability: maxProbability,
      step: 0.05,
    );

    var changed = false;
    for (var i = 0; i < competitors.length; i++) {
      final next = ladder[i];
      if ((competitors[i].dailyProbability - next).abs() > 0.000001 ||
          (competitors[i].weeklyProbability - next).abs() > 0.000001) {
        competitors[i].dailyProbability = next;
        competitors[i].weeklyProbability = next;
        changed = true;
      }
    }

    return changed;
  }

  static Future<String> loadDisplayTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(displayThemeKey) ?? 'yellow';
    return value == 'crimson' ? 'burgundy' : value;
  }

  static Future<void> saveDisplayTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(displayThemeKey, theme);
  }

  static Future<double> loadFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getDouble(fontScaleKey) ?? 1.0;
    return value.clamp(0.85, 1.25).toDouble();
  }

  static Future<void> saveFontScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(fontScaleKey, scale.clamp(0.85, 1.25).toDouble());
  }

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
    final competitors = List<Competitor>.from(
      (jsonDecode(competitorsData) as List).map((c) => Competitor.fromJson(c)),
    );

    // Migrate legacy defaults (daily 0.05..0.95, weekly all 1.0)
    // to the new 0.30..0.80 ladder for both daily and weekly probabilities.
    if (_shouldMigrateLegacyCompetitorProbabilities(competitors)) {
      final ladder = _buildProbabilityLadder(
        competitors.length,
        minProbability: 0.30,
        maxProbability: 0.80,
        step: 0.05,
      );

      for (var i = 0; i < competitors.length; i++) {
        competitors[i].dailyProbability = ladder[i];
        competitors[i].weeklyProbability = ladder[i];
      }

      await saveCompetitors(competitors);
    }

    if (_assignDefaultAvatarsToMissing(competitors)) {
      await saveCompetitors(competitors);
    }

    return competitors;
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
      'Creative Spark',
      'Pixel Pioneer',
      'Idea Forge',
      'Art Maven',
      'Design Wizard',
      'Craft Master',
      'Vision Seeker',
      'Muse Hunter',
      'Color Alchemist',
      'Form Shaper',
      'Story Weaver',
      'Rhythm Maker',
      'Canvas Dancer',
      'Mind Sculptor',
      'Dream Builder',
      'Skill Crafter',
      'Pattern Finder',
      'Concept Artist',
      'Flow State',
    ];

    final probabilities = _buildProbabilityLadder(
      names.length,
      minProbability: 0.30,
      maxProbability: 0.80,
      step: 0.05,
    );

    return List.generate(
      names.length,
      (i) => Competitor(
        name: names[i],
        avatarImagePath:
            _defaultCompetitorAvatarAssets[i %
                _defaultCompetitorAvatarAssets.length],
        points: 0,
        dailyProbability: probabilities[i],
        weeklyProbability: probabilities[i],
        // lastProcessedDay is null until the league is started
      ),
    );
  }

  static List<double> _buildProbabilityLadder(
    int count, {
    required double minProbability,
    required double maxProbability,
    required double step,
  }) {
    if (count <= 0) return const <double>[];

    final levels = ((maxProbability - minProbability) / step).round() + 1;
    if (levels <= 1) {
      return List<double>.filled(count, minProbability);
    }

    return List<double>.generate(count, (index) {
      final normalized = count == 1 ? 0.0 : index / (count - 1);
      final levelIndex = (normalized * (levels - 1)).round();
      return minProbability + (levelIndex * step);
    });
  }

  static bool _shouldMigrateLegacyCompetitorProbabilities(
    List<Competitor> competitors,
  ) {
    if (competitors.isEmpty) return false;

    const epsilon = 0.000001;
    bool equals(double a, double b) => (a - b).abs() < epsilon;

    final legacyDaily = competitors.asMap().entries.every((entry) {
      final expected = (entry.key + 1) * 0.05;
      return equals(entry.value.dailyProbability, expected);
    });

    final legacyWeekly = competitors.every(
      (competitor) => equals(competitor.weeklyProbability, 1.0),
    );

    return legacyDaily && legacyWeekly;
  }

  static bool _assignDefaultAvatarsToMissing(List<Competitor> competitors) {
    var changed = false;
    for (var i = 0; i < competitors.length; i++) {
      final currentPath = competitors[i].avatarImagePath;
      if (currentPath == null || currentPath.trim().isEmpty) {
        competitors[i].avatarImagePath =
            _defaultCompetitorAvatarAssets[i %
                _defaultCompetitorAvatarAssets.length];
        changed = true;
      }
    }
    return changed;
  }

  /// Called every time the virtual day advances (and on first startup to
  /// catch up any missed days). Requires [leagueStartDate] to be non-null -
  /// if the league has not been started, call this with null and it returns
  /// immediately without awarding anything.
  ///
  /// Rules (per day, for each competitor):
  ///   - Every completed day:  +3 points (if dailyProbability check passes)
  ///   - Every completed Sunday: additional +10 points (if weeklyProbability check passes)
  ///
  /// A day is "completed" once the clock has moved past it, i.e. we only
  /// process days strictly before today (yesterday and earlier).
  static Future<void> updateCompetitorPoints(
    List<Competitor> competitors,
    DateTime? leagueStartDate,
    List<Submission> userSubmissions,
  ) async {
    // League not started - nothing to do
    if (leagueStartDate == null) return;

    final now = DebugTime.now();
    // "today" as a date-only value (no time component)
    final DateTime today = DateTime(now.year, now.month, now.day);
    // The league start as a date-only value
    final DateTime leagueDay = DateTime(
      leagueStartDate.year,
      leagueStartDate.month,
      leagueStartDate.day,
    );
    final DateTime leagueEndDay = getLeagueEndDate(leagueDay);
    final DateTime processUntil = today.isAfter(leagueEndDay)
        ? leagueEndDay
        : today;

    if (processUntil.isBefore(leagueDay)) return;

    final dynamicDifficulty = await loadDynamicLeagueDifficulty();

    bool anyUpdated = false;
    final random = Random();

    for (final competitor in competitors) {
      final DateTime lastProcessed =
          competitor.lastProcessedDay ??
          leagueDay.subtract(const Duration(days: 1));

      // Nothing to process if already up to the process limit.
      if (!lastProcessed.isBefore(processUntil)) continue;

      DateTime cursor = lastProcessed.add(const Duration(days: 1));
      while (!cursor.isAfter(processUntil)) {
        final dailyModifier = dynamicDifficulty
            ? _dailySubmissionModifier(
                userSubmissions,
                referenceDay: cursor,
              )
            : 0.0;
        final weeklyModifier = dynamicDifficulty
            ? _weeklySubmissionModifier(
                userSubmissions,
                referenceDay: cursor,
              )
            : 0.0;

        // Every day: +3 points (base probability + activity modifier)
        if (_rollWithModifier(
          random,
          baseProbability: competitor.dailyProbability,
          modifier: dailyModifier,
        )) {
          competitor.points += 3;
        }

        // Every Sunday: +10 points (base probability + activity modifier)
        if (cursor.weekday == DateTime.sunday &&
            _rollWithModifier(
              random,
              baseProbability: competitor.weeklyProbability,
              modifier: weeklyModifier,
            )) {
          competitor.points += 10;
        }

        cursor = cursor.add(const Duration(days: 1));
      }

      competitor.lastProcessedDay = processUntil;
      anyUpdated = true;
    }

    if (anyUpdated) await saveCompetitors(competitors);
  }

  static bool _rollWithModifier(
    Random random, {
    required double baseProbability,
    required double modifier,
  }) {
    // Absolute probabilities are intentionally fixed and should not be affected
    // by activity-based modifiers.
    if (baseProbability <= 0.0) return false;
    if (baseProbability >= 1.0) return true;
    final adjusted = _applyModifier(baseProbability, modifier);
    return random.nextDouble() < adjusted;
  }

  static ({double adjusted, double modifier}) debugDailyProbability(
    List<Submission> submissions, {
    required double baseProbability,
    required DateTime referenceDay,
    required bool dynamicDifficulty,
  }) {
    if (!dynamicDifficulty) {
      return (adjusted: baseProbability, modifier: 0.0);
    }

    final modifier = _dailySubmissionModifier(
      submissions,
      referenceDay: referenceDay,
    );

    final adjusted =
        (baseProbability <= 0.0 || baseProbability >= 1.0)
        ? baseProbability
        : _applyModifier(baseProbability, modifier);

    return (adjusted: adjusted, modifier: modifier);
  }

  static ({double adjusted, double modifier}) debugWeeklyProbability(
    List<Submission> submissions, {
    required double baseProbability,
    required DateTime referenceDay,
    required bool dynamicDifficulty,
  }) {
    if (!dynamicDifficulty) {
      return (adjusted: baseProbability, modifier: 0.0);
    }

    final modifier = _weeklySubmissionModifier(
      submissions,
      referenceDay: referenceDay,
    );

    final adjusted =
        (baseProbability <= 0.0 || baseProbability >= 1.0)
        ? baseProbability
        : _applyModifier(baseProbability, modifier);

    return (adjusted: adjusted, modifier: modifier);
  }

  static double _applyModifier(double baseProbability, double modifier) {
    return (baseProbability + modifier).clamp(0.05, 0.95).toDouble();
  }

  static double _dailySubmissionModifier(
    List<Submission> submissions, {
    required DateTime referenceDay,
  }) {
    final day = DateTime(referenceDay.year, referenceDay.month, referenceDay.day);
    final windowStart = day.subtract(const Duration(days: 6));

    final recentDaily = submissions.where((s) {
      if (s.promptIndex < 0) return false;
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      return !d.isBefore(windowStart) && !d.isAfter(day);
    }).length;

    final recentAny = submissions.where((s) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      return !d.isAfter(day);
    }).toList();
    final mostRecent = recentAny.isEmpty
        ? null
        : recentAny
              .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
              .reduce((a, b) => a.isAfter(b) ? a : b);

    var modifier = 0.0;

    if (recentDaily >= 5) {
      modifier += 0.10;
    } else if (recentDaily >= 3) {
      modifier += 0.05;
    } else if (recentDaily == 0) {
      modifier -= 0.10;
    }

    if (mostRecent == null || day.difference(mostRecent).inDays >= 3) {
      modifier -= 0.05;
    }

    return modifier;
  }

  static double _weeklySubmissionModifier(
    List<Submission> submissions, {
    required DateTime referenceDay,
  }) {
    final day = DateTime(referenceDay.year, referenceDay.month, referenceDay.day);
    final windowStart = day.subtract(const Duration(days: 27));

    final completedWeekly = submissions.where((s) {
      if (s.promptIndex != -1 || s.points <= 0) return false;
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      return !d.isBefore(windowStart) && !d.isAfter(day);
    }).length;

    final recentAny = submissions.where((s) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      return !d.isAfter(day);
    }).toList();
    final mostRecent = recentAny.isEmpty
        ? null
        : recentAny
              .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
              .reduce((a, b) => a.isAfter(b) ? a : b);

    var modifier = 0.0;

    if (completedWeekly >= 3) {
      modifier += 0.10;
    } else if (completedWeekly >= 1) {
      modifier += 0.05;
    } else {
      modifier -= 0.10;
    }

    if (mostRecent == null || day.difference(mostRecent).inDays >= 7) {
      modifier -= 0.05;
    }

    return modifier;
  }

  static Future<DailyPromptState> loadDailyPrompts() async {
    final prefs = await SharedPreferences.getInstance();
    final promptsData = prefs.getString(dailyPromptsKey);

    if (promptsData == null) {
      final newState = await _createNewDailyPromptsAsync();
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
      final avoidTexts = state.prompts
          .map((p) => (p['text'] ?? '').toString())
          .where((t) => t.trim().isNotEmpty)
          .toList();
      final newState = await _createNewDailyPromptsAsync(avoidTexts: avoidTexts);
      await saveDailyPrompts(newState);
      return newState;
    }

    return state;
  }

  static Future<void> saveDailyPrompts(DailyPromptState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(dailyPromptsKey, jsonEncode(state.toJson()));
  }

  static String _dayKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  static Future<bool> hasUsedDailyPromptRefreshToday() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dayKey(DebugTime.now());
    return prefs.getString(dailyPromptRefreshDayKey) == todayKey;
  }

  static Future<Map<String, bool>> loadDailyPromptCategorySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(dailyPromptCategorySettingsKey);

    final defaults = <String, bool>{
      for (final category in promptCategories) category: true,
    };

    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }

    try {
      final parsed = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      for (final category in promptCategories) {
        final value = parsed[category];
        if (value is bool) {
          defaults[category] = value;
        }
      }
    } catch (_) {
      // Ignore malformed persisted settings and keep defaults.
    }

    if (!defaults.values.any((enabled) => enabled)) {
      for (final category in promptCategories) {
        defaults[category] = true;
      }
    }

    return defaults;
  }

  static Future<void> saveDailyPromptCategoryEnabled(
    String category,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadDailyPromptCategorySettings();
    current[category] = enabled;

    if (!current.values.any((v) => v)) {
      current[category] = true;
    }

    await prefs.setString(dailyPromptCategorySettingsKey, jsonEncode(current));
  }

  static Future<DailyPromptState> regenerateDailyPromptsForCategorySettingsChange() async {
    final refreshed = await _createNewDailyPromptsAsync();
    await saveDailyPrompts(refreshed);
    return refreshed;
  }

  static Future<DailyPromptState?> refreshDailyPromptsOncePerDay() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dayKey(DebugTime.now());

    if (prefs.getString(dailyPromptRefreshDayKey) == todayKey) {
      return null;
    }

    final current = await loadDailyPrompts();
    final avoidTexts = current.prompts
        .map((p) => (p['text'] ?? '').toString())
        .where((t) => t.trim().isNotEmpty)
        .toList();

    final refreshed = await _createNewDailyPromptsAsync(avoidTexts: avoidTexts);
    await saveDailyPrompts(refreshed);
    await prefs.setString(dailyPromptRefreshDayKey, todayKey);
    return refreshed;
  }

  static Future<({String text, int points})?> generateWeeklyTaskSuggestion({
    List<String> avoidTexts = const [],
  }) async {
    final reserved = avoidTexts
        .map((e) => e.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    const defaultPool = [
      'Complete a creative project from start to finish',
      'Document your entire creative process with photos',
      'Collaborate with someone else on a creative task',
      'Recreate your favorite artwork in a different medium',
      'Create something inspired by a random object you find',
      'Design and build a prototype of a product idea',
      'Write and illustrate a short comic or graphic novel',
      'Compose a playlist that tells a story',
      'Create a video essay about your favorite creative topic',
    ];

    for (final text in defaultPool) {
      final norm = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (!reserved.contains(norm)) {
        return (text: text, points: 8);
      }
    }

    return null;
  }

  static Future<DailyPromptState> _createNewDailyPromptsAsync({
    List<String> avoidTexts = const [],
  }) async {
    final random = Random();
    final enabledMap = await loadDailyPromptCategorySettings();
    final enabledCategories = enabledMap.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toSet();
    final dataset = await _loadPromptDataset();

    final prompts = <Map<String, dynamic>>[
      _pickPromptForPoints(
        dataset,
        points: 1,
        random: random,
        enabledCategories: enabledCategories,
        avoidTexts: avoidTexts,
      ),
      _pickPromptForPoints(
        dataset,
        points: 2,
        random: random,
        enabledCategories: enabledCategories,
        avoidTexts: avoidTexts,
      ),
      _pickPromptForPoints(
        dataset,
        points: 3,
        random: random,
        enabledCategories: enabledCategories,
        avoidTexts: avoidTexts,
      ),
    ];

    return DailyPromptState(
      prompts: prompts,
      date: DebugTime.now(),
      selectedPromptIndex: null,
    );
  }

  static Future<List<Map<String, dynamic>>> _loadPromptDataset() async {
    if (_promptDatasetCache != null) {
      return _promptDatasetCache!;
    }

    try {
      final raw = await rootBundle.loadString(promptDatasetAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _promptDatasetCache = const [];
        return _promptDatasetCache!;
      }

      final normalized = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final points = map['points'];
        final prompt = (map['prompt'] ?? '').toString().trim();
        final category = (map['category'] ?? '').toString().trim();
        final minutes = map['estimated_minutes'];

        if (prompt.isEmpty || category.isEmpty) continue;

        normalized.add({
          'points': points is int ? points : int.tryParse('$points') ?? 0,
          'text': prompt,
          'category': category,
          'estimated_minutes':
              minutes is int ? minutes : int.tryParse('$minutes') ?? 0,
        });
      }

      _promptDatasetCache = normalized;
      return _promptDatasetCache!;
    } catch (_) {
      _promptDatasetCache = const [];
      return _promptDatasetCache!;
    }
  }

  static Map<String, dynamic> _pickPromptForPoints(
    List<Map<String, dynamic>> dataset, {
    required int points,
    required Random random,
    required Set<String> enabledCategories,
    required List<String> avoidTexts,
  }) {
    final reserved = avoidTexts
        .map(_normalizePromptText)
        .where((text) => text.isNotEmpty)
        .toSet();

    bool inEnabledCategory(Map<String, dynamic> entry) {
      if (enabledCategories.isEmpty) return true;
      final category = (entry['category'] ?? '').toString();
      return enabledCategories.contains(category);
    }

    final withFilters = dataset.where((entry) {
      if ((entry['points'] ?? 0) != points) return false;
      if (!inEnabledCategory(entry)) return false;
      final text = _normalizePromptText((entry['text'] ?? '').toString());
      if (text.isEmpty) return false;
      return !reserved.contains(text);
    }).toList();

    final categoryOnly = dataset.where((entry) {
      if ((entry['points'] ?? 0) != points) return false;
      if (!inEnabledCategory(entry)) return false;
      return _normalizePromptText((entry['text'] ?? '').toString()).isNotEmpty;
    }).toList();

    final byPoints = dataset.where((entry) {
      if ((entry['points'] ?? 0) != points) return false;
      return _normalizePromptText((entry['text'] ?? '').toString()).isNotEmpty;
    }).toList();

    final candidatePool = withFilters.isNotEmpty
        ? withFilters
        : (categoryOnly.isNotEmpty ? categoryOnly : byPoints);

    if (candidatePool.isNotEmpty) {
      final chosen = candidatePool[random.nextInt(candidatePool.length)];
      return {
        'text': chosen['text'],
        'points': points,
        'category': chosen['category'],
        'estimated_minutes': chosen['estimated_minutes'],
      };
    }

    return _getFallbackPromptFromLegacyPool(points, random);
  }

  static String _normalizePromptText(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Map<String, dynamic> _getFallbackPromptFromLegacyPool(
    int points,
    Random random,
  ) {
    final pool = switch (points) {
      1 => _legacyOnePointPrompts,
      2 => _legacyTwoPointPrompts,
      _ => _legacyThreePointPrompts,
    };
    final promptText = pool[random.nextInt(pool.length)];
    return {
      'text': promptText,
      'points': points,
      'category': 'General',
      'estimated_minutes': points == 1 ? 10 : (points == 2 ? 20 : 35),
    };
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

  /// Returns the last day (inclusive) of a 4-week league window.
  static DateTime getLeagueEndDate(DateTime leagueStartDate) {
    final start = DateTime(
      leagueStartDate.year,
      leagueStartDate.month,
      leagueStartDate.day,
    );
    return start.add(const Duration(days: 27));
  }

  static final List<String> _legacyOnePointPrompts = [
    'Write a short poem about your day',
    'Take one photo that captures your mood',
    'Write three lines describing a memory',
    'Sketch a tiny icon in 5 minutes',
    'Make a one-sentence story starter',
    'List five words that describe today',
  ];

  static final List<String> _legacyTwoPointPrompts = [
    'Draw a picture in 30 minutes',
    'Create a simple logo concept for a fake brand',
    'Write a 150-word micro-story with a twist',
    'Record a 20-second voiceover about your week',
    'Design a quick moodboard with 5 references',
  ];

  static final List<String> _legacyThreePointPrompts = [
    'Record a demo song',
    'Create a 60-second video showcasing a concept',
    'Build a before/after redesign of one everyday object',
    'Write and perform a short spoken-word piece',
    'Produce a mini project update with visuals and narration',
  ];
}
