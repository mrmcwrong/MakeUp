part of '../main.dart';

class WeeklyTaskScreen extends StatefulWidget {
  final User user;
  final Function(User) onUserUpdate;
  final VoidCallback? onReload;
  final bool isActive;

  const WeeklyTaskScreen({
    super.key,
    required this.user,
    required this.onUserUpdate,
    this.onReload,
    this.isActive = true,
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
  List<String> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    _taskController = TextEditingController();
    _completionController = TextEditingController();
    _pointsController = TextEditingController(text: '10');
    _loadWeeklyTask();
  }

  @override
  void didUpdateWidget(WeeklyTaskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user && widget.isActive) {
      _loadWeeklyTask();
    }
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _loadWeeklyTask();
      }
    }
  }

  @override
  void dispose() {
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

  Duration _timeUntilNextWeek() {
    final now = DebugTime.now();
    final daysUntilMonday = (8 - now.weekday) % 7;
    final nextMonday = DateTime(
      now.year,
      now.month,
      now.day + (daysUntilMonday == 0 ? 7 : daysUntilMonday),
    );
    final remaining = nextMonday.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
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
          content: Text(
            'Please enter a task description',
            style: GoogleFonts.dmSans(),
          ),
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
          content: Text(
            'Please describe what you did or attach a file',
            style: GoogleFonts.dmSans(),
          ),
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
      text:
          '${completedTask.taskText}\n\nCompletion: ${_completionController.text}',
      points: completedTask.points,
      date: DebugTime.now(),
      promptIndex: -1,
      dayKey: completedTask.weekKey,
      attachments: List.from(_pendingAttachments),
    );

    final updatedSubmissions = [
      ...widget.user.submissions.where((s) => s.id != completedTask.id),
      completedSubmission,
    ];

    final updatedUser = User(
      username: widget.user.username,
      avatarImagePath: widget.user.avatarImagePath,
      avatarFrameShape: widget.user.avatarFrameShape,
      showAvatarFrame: widget.user.showAvatarFrame,
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
            child: Text(
              "Cancel",
              style: GoogleFonts.dmSans(color: AppColors.brown),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Delete",
              style: GoogleFonts.dmSans(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final updatedSubmissions = widget.user.submissions.where((submission) {
      return !(submission.promptIndex == -1 &&
          submission.dayKey == _weeklyTask!.weekKey);
    }).toList();

    final updatedUser = User(
      username: widget.user.username,
      avatarImagePath: widget.user.avatarImagePath,
      avatarFrameShape: widget.user.avatarFrameShape,
      showAvatarFrame: widget.user.showAvatarFrame,
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
        appBar: AppBar(
          leadingWidth: 88,
          leading: buildStreakLeading(widget.user),
          title: const Text('Weekly Challenge'),
        ),
        body: Center(child: CircularProgressIndicator(color: AppColors.amber)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 88,
        leading: buildStreakLeading(widget.user),
        title: const Text('Weekly Challenge'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: _weeklyTask == null
            ? _buildCreateTaskForm()
            : _buildExistingTask(),
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
            widget.isActive
                ? StreamBuilder<int>(
                    stream: Stream.periodic(
                      const Duration(seconds: 1),
                      (tick) => tick,
                    ),
                    initialData: 0,
                    builder: (_, _) => Text(
                      '${_formatCountdown(_timeUntilNextWeek())} until next week',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : Text(
                    '${_formatCountdown(_timeUntilNextWeek())} until next week',
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
          style: GoogleFonts.dmSans(
            fontSize: 16,
            color: AppColors.textPrimary,
            height: 1.5,
          ),
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
                    borderSide: BorderSide(
                      color: AppColors.golden.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.golden.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.amber, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Choose between 1-15 points based on difficulty',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: Text(
              'Create Challenge',
              style: GoogleFonts.dmSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
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
            widget.isActive
                ? StreamBuilder<int>(
                    stream: Stream.periodic(
                      const Duration(seconds: 1),
                      (tick) => tick,
                    ),
                    initialData: 0,
                    builder: (_, _) => Text(
                      '${_formatCountdown(_timeUntilNextWeek())} until next week',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : Text(
                    '${_formatCountdown(_timeUntilNextWeek())} until next week',
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
            color: _weeklyTask!.isCompleted
                ? AppColors.lightYellow
                : Colors.white,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
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
                    Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    ),
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
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
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
          // Attachments editor
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: Text(
                'Complete Challenge',
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
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
