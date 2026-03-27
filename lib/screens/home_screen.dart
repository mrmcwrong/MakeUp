part of '../main.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  final Function(User) onUserUpdate;
  final VoidCallback? onReload;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onUserUpdate,
    this.onReload,
  });

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
  bool _hasUsedRefreshToday = false;

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

  void reloadForPromptSettingsChange() {
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
    final usedRefreshToday = await StorageService.hasUsedDailyPromptRefreshToday();
    if (!mounted) return;
    setState(() {
      dailyPrompts = state.prompts;
      selectedPromptIndex = state.selectedPromptIndex;
      _submissionController.clear();
      _hasUsedRefreshToday = usedRefreshToday;
      _isLoading = false;
    });
  }

  Future<void> _refreshDailyPrompts() async {
    if (_hasSubmittedAnyPromptToday()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You cannot refresh after submitting today.',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final refreshed = await StorageService.refreshDailyPromptsOncePerDay();
    if (!mounted) return;

    if (refreshed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can only refresh prompts once per day.',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      dailyPrompts = refreshed.prompts;
      selectedPromptIndex = null;
      _pendingAttachments = [];
      _submissionController.clear();
      _hasUsedRefreshToday = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Daily prompts refreshed.',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  AppBar _buildDailyAppBar() {
    final canRefresh = !_hasUsedRefreshToday && !_hasSubmittedAnyPromptToday();
    return AppBar(
      leadingWidth: 88,
      leading: buildStreakLeading(widget.user),
      title: const Text('Daily Prompts'),
      actions: [
        IconButton(
          tooltip: _hasUsedRefreshToday
              ? 'Already refreshed today'
              : 'Refresh prompts (once/day)',
          onPressed: canRefresh ? _refreshDailyPrompts : null,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
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
          content: Text(
            'You already submitted today.',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_submissionController.text.isEmpty && _pendingAttachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a response or attach a file',
            style: GoogleFonts.dmSans(),
          ),
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
        appBar: _buildDailyAppBar(),
        body: Center(child: CircularProgressIndicator(color: AppColors.amber)),
      );
    }

    return Scaffold(
      appBar: _buildDailyAppBar(),
      body: selectedPromptIndex == null
          ? Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
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
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        final prompt = dailyPrompts[index];
                        final isSubmitted = _alreadySubmittedToday(index);
                        return InkWell(
                          onTap: isSubmitted
                              ? null
                              : () => _selectPrompt(index),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isSubmitted
                                  ? AppColors.warmSurface
                                  : Colors.white,
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
                                        color: AppColors.golden.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                      Icon(
                                        Icons.check_circle,
                                        color: AppColors.success,
                                        size: 24,
                                      ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
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
                          icon: Icon(
                            Icons.refresh,
                            size: 16,
                            color: AppColors.brown,
                          ),
                          label: Text(
                            'Change',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brown,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
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
                        borderSide: BorderSide(
                          color: AppColors.amber,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Attachments editor
                  AttachmentsEditor(
                    attachments: _pendingAttachments,
                    onAdd: _addAttachments,
                    onRemove: (i) =>
                        setState(() => _pendingAttachments.removeAt(i)),
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
