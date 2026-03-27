part of '../main.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final Function(User) onUserUpdate;
  final Future<void> Function() onLeagueReset;
  final VoidCallback onDisplaySettingsChanged;
  final Future<void> Function()? onLeagueSettingsChanged;
  final Future<void> Function()? onDailyPromptSettingsChanged;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onUserUpdate,
    required this.onLeagueReset,
    required this.onDisplaySettingsChanged,
    this.onLeagueSettingsChanged,
    this.onDailyPromptSettingsChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
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
                'Edit Your Profile',
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final newName = nameController.text.trim().isEmpty
                        ? widget.user.username
                        : nameController.text.trim();
                    widget.onUserUpdate(
                      User(
                        username: newName,
                        avatarImagePath: currentImagePath,
                        totalPoints: widget.user.totalPoints,
                        submissions: widget.user.submissions,
                      ),
                    );
                    Navigator.pop(sheetContext);
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

  String _formatDateTime(DateTime date) {
    return '${date.month}/${date.day}/${date.year} - '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _getDayOfWeek(DateTime date) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
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

      if (isWeekly &&
          !_showInProgress &&
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
      appBar: AppBar(
        leadingWidth: 88,
        leading: buildStreakLeading(widget.user),
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: Icon(Icons.settings_outlined, color: AppColors.brown),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    onLeagueReset: widget.onLeagueReset,
                    onDisplaySettingsChanged:
                        widget.onDisplaySettingsChanged,
                    onLeagueSettingsChanged: widget.onLeagueSettingsChanged,
                    onDailyPromptSettingsChanged:
                        widget.onDailyPromptSettingsChanged,
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
                          AvatarWidget(
                            imagePath: widget.user.avatarImagePath,
                            size: 100,
                            isUser: true,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppColors.amber,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.photo_library_outlined,
                                size: 15,
                                color: Colors.white,
                              ),
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
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
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
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
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
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
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
                    borderSide: BorderSide(
                      color: AppColors.golden.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.golden.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.amber, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                        border: Border.all(
                          color: AppColors.golden.withValues(alpha: 0.2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterType,
                          icon: Icon(
                            Icons.filter_list,
                            color: AppColors.brown,
                            size: 20,
                          ),
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          dropdownColor: AppColors.warmSurface,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => _filterType = newValue);
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                              value: 'daily',
                              child: Text('Daily'),
                            ),
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text('Weekly'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () =>
                        setState(() => _sortNewestFirst = !_sortNewestFirst),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warmSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.golden.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        _sortNewestFirst
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: AppColors.brown,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () =>
                        setState(() => _showInProgress = !_showInProgress),
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
                        color: _showInProgress
                            ? AppColors.amber
                            : AppColors.brown,
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
                            color: isCompleted
                                ? AppColors.lightYellow
                                : AppColors.warmSurface,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.amber,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_month,
                                              size: 14,
                                              color: Colors.white,
                                            ),
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.golden,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Icon(
                                      isCompleted
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: isCompleted
                                          ? AppColors.success
                                          : AppColors.amber,
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
                                Divider(
                                  color: AppColors.golden.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
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
                                // Attachments viewer
                                AttachmentsViewer(
                                  attachments: submission.attachments,
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Unfinished',
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.brown,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.today,
                                              size: 14,
                                              color: Colors.white,
                                            ),
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.golden,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: AppColors.error,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor:
                                              AppColors.warmSurface,
                                          title: Text(
                                            "Delete submission?",
                                            style: GoogleFonts.dmSans(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          content: Text(
                                            "This will remove the submission and its points. If this is today's submission, you'll be able to resubmit.",
                                            style: GoogleFonts.dmSans(),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text(
                                                "Cancel",
                                                style: GoogleFonts.dmSans(
                                                  color: AppColors.brown,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: Text(
                                                "Delete",
                                                style: GoogleFonts.dmSans(
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (!context.mounted) return;

                                      if (confirmed == true) {
                                        final updatedSubmissions =
                                            List<Submission>.from(
                                              widget.user.submissions,
                                            )..removeWhere(
                                              (s) => s.id == submission.id,
                                            );

                                        final updatedUser = User(
                                          username: widget.user.username,
                                          avatarImagePath:
                                              widget.user.avatarImagePath,
                                          totalPoints:
                                              widget.user.totalPoints -
                                              submission.points,
                                          submissions: updatedSubmissions,
                                        );

                                        widget.onUserUpdate(updatedUser);

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Submission deleted",
                                              style: GoogleFonts.dmSans(),
                                            ),
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
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.7,
                                  ),
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
                              // Attachments viewer
                              AttachmentsViewer(
                                attachments: submission.attachments,
                              ),
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
