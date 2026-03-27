part of '../main.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<Map<String, dynamic>> _dataFuture;
  int _resetKey = 0;
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _loadDisplaySettings();
  }

  Future<void> _loadDisplaySettings() async {
    final theme = await StorageService.loadDisplayTheme();
    final fontScale = await StorageService.loadFontScale();

    AppColors.setTheme(theme);
    if (!mounted) return;

    setState(() {
      _fontScale = fontScale;
    });
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
        themeAnimationDuration: Duration.zero,
        themeAnimationCurve: Curves.linear,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(_fontScale),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
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
                  child: CircularProgressIndicator(color: AppColors.amber),
                ),
              );
            }
            return MainNavigationScreen(
              key: ValueKey(_resetKey),
              user: snapshot.data!['user'],
              competitors: snapshot.data!['competitors'],
              onDisplaySettingsChanged: _loadDisplaySettings,
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
  final VoidCallback onDisplaySettingsChanged;

  const MainNavigationScreen({
    super.key,
    required this.user,
    required this.competitors,
    required this.onDisplaySettingsChanged,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late User user;
  late List<Competitor> competitors;
  DateTime? _leagueStartDate; // null = league not yet started
  Timer? _masterTimer;
  DateTime? _lastCheckedDate; // the last date we processed points for
  String? _lastCheckedWeekKey;

  final GlobalKey<_HomeScreenState> _homeKey = GlobalKey<_HomeScreenState>();
  final GlobalKey<_WeeklyTaskScreenState> _weeklyKey =
      GlobalKey<_WeeklyTaskScreenState>();

  @override
  void initState() {
    super.initState();
    user = widget.user;
    competitors = widget.competitors;
    _loadLeagueAndStart();
  }

  Future<void> _loadLeagueAndStart() async {
    _leagueStartDate = await StorageService.loadLeagueStartDate();
    final now = DebugTime.now();
    // Pre-set to yesterday so the first tick catches up any missed days
    _lastCheckedDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    _lastCheckedWeekKey = StorageService.getWeekKey(now);
    _masterTick();
    _masterTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _masterTick();
    });
  }

  /// Call this when the user presses "Begin League" to start awarding points.
  Future<void> _startLeague() async {
    final now = DebugTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await StorageService.saveLeagueStartDate(today);
    // Reset all competitors so points begin from zero at league start
    for (final c in competitors) {
      c.points = 0;
      c.lastProcessedDay = null;
    }
    await StorageService.saveCompetitors(competitors);
    if (mounted) setState(() => _leagueStartDate = today);
  }

  Future<void> _forfeitAndRestartLeague() async {
    await _startLeague();
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

    // Competitor points (daily + Sunday bonus)
    // Runs every time the virtual day advances. The method returns immediately
    // if _leagueStartDate is null (league not started yet).
    final bool isNewDay =
        _lastCheckedDate != null && todayDate.isAfter(_lastCheckedDate!);

    if (isNewDay) {
      await StorageService.updateCompetitorPoints(
        competitors,
        _leagueStartDate,
        user.submissions,
      );
      if (mounted) setState(() => competitors = List.from(competitors));
      _lastCheckedDate = todayDate;
      _homeKey.currentState?.reloadForNewDay();
    } else {
      _lastCheckedDate ??= todayDate;
    }

    // UI reload for new week
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

  Future<void> _reloadCompetitorsFromStorage() async {
    final loaded = await StorageService.loadCompetitors();
    if (!mounted) return;
    setState(() {
      competitors = loaded;
    });
  }

  Future<void> _reloadDailyPromptsFromSettings() async {
    _homeKey.currentState?.reloadForPromptSettingsChange();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(key: _homeKey, user: user, onUserUpdate: _updateUser),
          WeeklyTaskScreen(
            key: _weeklyKey,
            user: user,
            onUserUpdate: _updateUser,
          ),
          LeagueScreen(
            user: user,
            competitors: competitors,
            onUserUpdate: _updateUser,
            onCompetitorsUpdate: (updated) {
              setState(() {
                competitors = updated;
              });
              StorageService.saveCompetitors(updated);
            },
            leagueStartDate: _leagueStartDate,
            onLeagueStart: _startLeague,
          ),
          ProfileScreen(
            user: user,
            onUserUpdate: _updateUser,
            onLeagueReset: _forfeitAndRestartLeague,
            onDisplaySettingsChanged: widget.onDisplaySettingsChanged,
            onLeagueSettingsChanged: _reloadCompetitorsFromStorage,
            onDailyPromptSettingsChanged: _reloadDailyPromptsFromSettings,
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
            selectedIcon: Icon(
              Icons.calendar_month,
              color: AppColors.darkBrown,
            ),
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
