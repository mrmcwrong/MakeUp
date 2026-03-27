part of '../main.dart';

class LeagueScreen extends StatefulWidget {
  final User user;
  final List<Competitor> competitors;
  final Function(User) onUserUpdate;
  final Function(List<Competitor>) onCompetitorsUpdate;
  final DateTime? leagueStartDate;
  final VoidCallback onLeagueStart;

  const LeagueScreen({
    super.key,
    required this.user,
    required this.competitors,
    required this.onUserUpdate,
    required this.onCompetitorsUpdate,
    required this.leagueStartDate,
    required this.onLeagueStart,
  });

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  late List<Map<String, dynamic>> leaderboard;
  bool _dynamicDifficulty = true;
  bool _showIndividualProbabilitySelectors = true;

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime? _leagueEndDate() {
    final start = widget.leagueStartDate;
    if (start == null) return null;
    return StorageService.getLeagueEndDate(start);
  }

  bool _isLeagueEnded() {
    final end = _leagueEndDate();
    if (end == null) return false;
    final today = _dateOnly(DebugTime.now());
    return today.isAfter(end);
  }

  int _userLeaguePoints() {
    final start = widget.leagueStartDate;
    if (start == null) return 0;

    final startDay = _dateOnly(start);
    final endDay = StorageService.getLeagueEndDate(startDay);

    var sum = 0;
    for (final submission in widget.user.submissions) {
      final d = _dateOnly(submission.date);
      if (!d.isBefore(startDay) && !d.isAfter(endDay)) {
        sum += submission.points;
      }
    }
    return sum;
  }

  int _userLeagueRank() {
    _buildLeaderboard();
    final index = leaderboard.indexWhere((entry) => entry['isUser'] == true);
    return index == -1 ? leaderboard.length : index + 1;
  }

  String _formatShortDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  int _daysUntilLeagueEnd() {
    final end = _leagueEndDate();
    if (end == null) return 0;

    final today = _dateOnly(DebugTime.now());
    final endDay = _dateOnly(end);
    return max(0, endDay.difference(today).inDays);
  }

  Future<void> _confirmAndStartLeague() async {
    final hasStartedBefore = widget.leagueStartDate != null;

    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.warmSurface,
        title: Text(
          hasStartedBefore ? 'Start Next League?' : 'Begin 4-Week League?',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          hasStartedBefore
              ? 'This starts a brand new 4-week season today and resets all competitor scores.'
              : 'Points will begin counting from today for all competitors.',
          style: GoogleFonts.dmSans(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: AppColors.brown),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              hasStartedBefore ? 'Start Next League' : 'Begin League',
              style: GoogleFonts.dmSans(color: AppColors.amber),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (shouldStart == true) {
      widget.onLeagueStart();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLeagueSettings();
    _buildLeaderboard();
  }

  @override
  void didUpdateWidget(covariant LeagueScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadLeagueSettings();
  }

  Future<void> _loadLeagueSettings() async {
    final dynamicDifficulty = await StorageService.loadDynamicLeagueDifficulty();
    final showIndividualProbabilitySelectors =
        await StorageService.loadShowIndividualProbabilitySelectors();
    if (!mounted) return;
    setState(() {
      _dynamicDifficulty = dynamicDifficulty;
      _showIndividualProbabilitySelectors = showIndividualProbabilitySelectors;
    });
  }

  void _buildLeaderboard() {
    leaderboard = [
      {
        'name': widget.user.username,
        'imagePath': widget.user.avatarImagePath,
        'points': _userLeaguePoints(),
        'isUser': true,
        'competitor': null,
      },
      ...widget.competitors.map(
        (c) => {
          'name': c.name,
          'imagePath': c.avatarImagePath,
          'points': c.points,
          'isUser': false,
          'competitor': c,
        },
      ),
    ];
    leaderboard.sort(
      (a, b) => (b['points'] as int).compareTo(a['points'] as int),
    );
  }

  Future<void> _showEditSheet({
    required bool isUser,
    Competitor? competitor,
  }) async {
    final nameController = TextEditingController(
      text: isUser ? widget.user.username : competitor!.name,
    );
    String? currentImagePath = isUser
        ? widget.user.avatarImagePath
        : competitor!.avatarImagePath;
    double currentDailyProb = competitor?.dailyProbability ?? 0.5;
    double currentWeeklyProb = competitor?.weeklyProbability ?? 1.0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUser ? 'Edit Your Profile' : 'Edit Competitor',
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepBrown,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final path = await pickAndSaveAvatar(ImageSource.gallery);
                    if (path != null) {
                      setSheetState(() => currentImagePath = path);
                    }
                  },
                  child: Stack(
                    children: [
                      AvatarWidget(
                        imagePath: currentImagePath,
                        size: 90,
                        isUser: true,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.photo_library_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Name',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.golden.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.golden.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.amber, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              // Probability sliders (competitors only, optional)
              if (!isUser && _showIndividualProbabilitySelectors) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.golden.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scoring Probabilities',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Daily probability
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.today,
                                size: 15,
                                color: AppColors.brown,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Daily (+3 pts)',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lightYellow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.golden.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '${(currentDailyProb * 100).round()}%',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkBrown,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                          activeTrackColor: AppColors.amber,
                          inactiveTrackColor: AppColors.golden.withValues(
                            alpha: 0.25,
                          ),
                          thumbColor: AppColors.brown,
                          overlayColor: AppColors.amber.withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          value: currentDailyProb,
                          onChanged: (val) =>
                              setSheetState(() => currentDailyProb = val),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Weekly probability
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 15,
                                color: AppColors.brown,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Weekly Sunday (+10 pts)',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lightYellow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.golden.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '${(currentWeeklyProb * 100).round()}%',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkBrown,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                          activeTrackColor: AppColors.amber,
                          inactiveTrackColor: AppColors.golden.withValues(
                            alpha: 0.25,
                          ),
                          thumbColor: AppColors.brown,
                          overlayColor: AppColors.amber.withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          value: currentWeeklyProb,
                          onChanged: (val) =>
                              setSheetState(() => currentWeeklyProb = val),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chance this competitor earns points each day / Sunday',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
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
                      final didChangeBaseProbabilities =
                          _showIndividualProbabilitySelectors &&
                          ((competitor!.dailyProbability - currentDailyProb).abs() >
                                  0.000001 ||
                              (competitor.weeklyProbability - currentWeeklyProb).abs() >
                                  0.000001);

                      competitor!.name = newName;
                      competitor.avatarImagePath = currentImagePath;
                      if (_showIndividualProbabilitySelectors) {
                        competitor.dailyProbability = currentDailyProb;
                        competitor.weeklyProbability = currentWeeklyProb;
                      }

                      if (didChangeBaseProbabilities) {
                        await StorageService.saveLeagueDifficultyPreset('custom');
                      }

                      await StorageService.saveCompetitors(widget.competitors);
                      widget.onCompetitorsUpdate(widget.competitors);
                    }
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    setState(() {
                      _buildLeaderboard();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
      case 1:
        return AppColors.golden;
      case 2:
        return AppColors.brown.withValues(alpha: 0.6);
      case 3:
        return AppColors.brown.withValues(alpha: 0.4);
      default:
        return AppColors.brown;
    }
  }

  @override
  Widget build(BuildContext context) {
    _buildLeaderboard();
    final bool leagueStarted = widget.leagueStartDate != null;
    final bool leagueEnded = leagueStarted && _isLeagueEnded();
    final DateTime? leagueEndDate = _leagueEndDate();
    final int daysLeft = _daysUntilLeagueEnd();

    final showProbabilityDebug = DebugOptions.showAdjustedProbabilities;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 88,
        leading: buildStreakLeading(widget.user),
        title: const Text('League'),
      ),
      body: leagueStarted
          ? leagueEnded
                ? _buildLeagueEndedOverlay(context)
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 32.0,
                    ),
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
                          'Long-press any competitor to edit name, photo & scoring probabilities',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        if (leagueEndDate != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warmSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.golden.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.hourglass_bottom,
                                  size: 18,
                                  color: AppColors.brown,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    daysLeft == 0
                                        ? 'League ends today'
                                        : 'League ends in $daysLeft day${daysLeft == 1 ? '' : 's'}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatShortDate(leagueEndDate),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                                final today = DebugTime.now();
                                final dailyDebug = competitor == null
                                  ? null
                                  : StorageService.debugDailyProbability(
                                    widget.user.submissions,
                                    baseProbability: competitor.dailyProbability,
                                    referenceDay: today,
                                    dynamicDifficulty: _dynamicDifficulty,
                                  );
                                final weeklyDebug = competitor == null
                                  ? null
                                  : StorageService.debugWeeklyProbability(
                                    widget.user.submissions,
                                    baseProbability:
                                      competitor.weeklyProbability,
                                    referenceDay: today,
                                    dynamicDifficulty: _dynamicDifficulty,
                                  );

                              return GestureDetector(
                                onLongPress: () => _showEditSheet(
                                  isUser: isUser,
                                  competitor: competitor,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? AppColors.lightYellow
                                        : Colors.white,
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
                                              color: AppColors.golden.withValues(
                                                alpha: 0.15,
                                              ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry['name'] as String,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 16,
                                                fontWeight: isUser
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            if (showProbabilityDebug &&
                                                competitor != null &&
                                                dailyDebug != null &&
                                                weeklyDebug != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  'D ${_pct(competitor.dailyProbability)} -> ${_pct(dailyDebug.adjusted)} (${_signedPct(dailyDebug.modifier)})   W ${_pct(competitor.weeklyProbability)} -> ${_pct(weeklyDebug.adjusted)} (${_signedPct(weeklyDebug.modifier)})',
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 10,
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
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
                  )
          : _buildNotStartedOverlay(context),
    );
  }

  String _pct(double value) => '${(value * 100).round()}%';

  String _signedPct(double value) {
    final pct = (value * 100).round();
    if (pct > 0) return '+$pct%';
    return '$pct%';
  }

  Widget _buildNotStartedOverlay(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, size: 72, color: AppColors.golden),
            const SizedBox(height: 24),
            Text(
              '4-Week League',
              style: GoogleFonts.dmSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.deepBrown,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Compete against opponents over 4 weeks. Points are awarded daily and every Sunday.',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmAndStartLeague,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Begin 4-Week League',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeagueEndedOverlay(BuildContext context) {
    final start = widget.leagueStartDate;
    final end = _leagueEndDate();

    if (start == null || end == null) {
      return _buildNotStartedOverlay(context);
    }

    final rank = _userLeagueRank();
    final totalPlayers = leaderboard.length;
    final userPoints = _userLeaguePoints();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final standingsHeight =
              (constraints.maxHeight * 0.30).clamp(120.0, 220.0).toDouble();

          return SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.golden.withValues(alpha: 0.45),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.golden.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Icon(
                      Icons.emoji_events,
                      size: 64,
                      color: AppColors.golden,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'League Complete',
                      style: GoogleFonts.dmSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepBrown,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '${_formatShortDate(start)} - ${_formatShortDate(end)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightYellow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.golden.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your Final Position',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$rank / $totalPlayers',
                          style: GoogleFonts.dmSans(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepBrown,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$userPoints pts',
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Final Standings',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: standingsHeight,
                    decoration: BoxDecoration(
                      color: AppColors.warmSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.golden.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: leaderboard.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = leaderboard[index];
                          final isUser = entry['isUser'] as bool;

                          return Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${index + 1}.',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry['name'] as String,
                                  style: GoogleFonts.dmSans(
                                    fontWeight: isUser
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${entry['points']} pts',
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkBrown,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirmAndStartLeague,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Start Next League',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

///
/// SETTINGS SCREEN
