part of '../main.dart';

class SettingsScreen extends StatefulWidget {
  final Future<void> Function() onLeagueReset;
  final VoidCallback onDisplaySettingsChanged;
  final Future<void> Function()? onLeagueSettingsChanged;
  final Future<void> Function()? onDailyPromptSettingsChanged;

  const SettingsScreen({
    super.key,
    required this.onLeagueReset,
    required this.onDisplaySettingsChanged,
    this.onLeagueSettingsChanged,
    this.onDailyPromptSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _dynamicLeagueDifficulty = true;
  String _leagueDifficultyPreset = 'medium';
  bool _showIndividualProbabilitySelectors = true;
  String _displayTheme = 'yellow';
  double _fontScale = 1.0;
  bool _leagueSectionOpen = false;
  bool _displaySectionOpen = false;
  bool _dailyPromptsSectionOpen = false;
  Map<String, bool> _dailyPromptCategoryEnabled = {
    for (final category in StorageService.promptCategories) category: true,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final dynamicDifficulty =
        await StorageService.loadDynamicLeagueDifficulty();
    final difficultyPreset = await StorageService.loadLeagueDifficultyPreset();
    final showIndividualProbabilitySelectors =
      await StorageService.loadShowIndividualProbabilitySelectors();
    final displayTheme = await StorageService.loadDisplayTheme();
    final fontScale = await StorageService.loadFontScale();
    final dailyPromptCategoryEnabled =
        await StorageService.loadDailyPromptCategorySettings();

    AppColors.setTheme(displayTheme);
    if (!mounted) return;

    setState(() {
      _dynamicLeagueDifficulty = dynamicDifficulty;
      _leagueDifficultyPreset = difficultyPreset;
      _showIndividualProbabilitySelectors = showIndividualProbabilitySelectors;
      _displayTheme = displayTheme;
      _fontScale = fontScale;
      _dailyPromptCategoryEnabled = dailyPromptCategoryEnabled;
      _isLoading = false;
    });
  }

  Future<void> _setDailyPromptCategoryEnabled(
    String category,
    bool enabled,
  ) async {
    final enabledCount =
        _dailyPromptCategoryEnabled.values.where((v) => v).length;
    final currentlyEnabled = _dailyPromptCategoryEnabled[category] ?? true;

    if (!enabled && currentlyEnabled && enabledCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'At least one prompt category must stay enabled.',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _dailyPromptCategoryEnabled[category] = enabled;
    });

    await StorageService.saveDailyPromptCategoryEnabled(category, enabled);
    await StorageService.regenerateDailyPromptsForCategorySettingsChange();
    await widget.onDailyPromptSettingsChanged?.call();
  }

  Future<void> _enableAllPromptCategories() async {
    for (final category in StorageService.promptCategories) {
      _dailyPromptCategoryEnabled[category] = true;
      await StorageService.saveDailyPromptCategoryEnabled(category, true);
    }
    if (!mounted) return;
    setState(() {});
    await StorageService.regenerateDailyPromptsForCategorySettingsChange();
    await widget.onDailyPromptSettingsChanged?.call();
  }

  Future<void> _setDisplayTheme(String theme) async {
    setState(() => _displayTheme = theme);
    AppColors.setTheme(theme);
    await StorageService.saveDisplayTheme(theme);
    widget.onDisplaySettingsChanged();
  }

  Future<void> _applyLeagueDifficultyNow() async {
    final competitors = await StorageService.loadCompetitors();
    if (StorageService.applyLeagueDifficultyPreset(
      competitors,
      _leagueDifficultyPreset,
    )) {
      await StorageService.saveCompetitors(competitors);
    }
    await widget.onLeagueSettingsChanged?.call();
  }

  Future<void> _setDynamicLeagueDifficulty(bool value) async {
    setState(() => _dynamicLeagueDifficulty = value);
    await StorageService.saveDynamicLeagueDifficulty(value);
    await widget.onLeagueSettingsChanged?.call();
  }

  Future<void> _setLeagueDifficultyPreset(String preset) async {
    if (preset == _leagueDifficultyPreset) return;

    final shouldApply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.warmSurface,
        title: Text(
          'Apply Difficulty Preset?',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will immediately overwrite all competitors\' base daily and weekly probabilities. Continue?',
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
              'Apply Preset',
              style: GoogleFonts.dmSans(color: AppColors.amber),
            ),
          ),
        ],
      ),
    );

    if (shouldApply != true || !mounted) return;

    setState(() => _leagueDifficultyPreset = preset);
    await StorageService.saveLeagueDifficultyPreset(preset);
    await _applyLeagueDifficultyNow();
  }

  Future<void> _setShowIndividualProbabilitySelectors(bool value) async {
    setState(() => _showIndividualProbabilitySelectors = value);
    await StorageService.saveShowIndividualProbabilitySelectors(value);
    await widget.onLeagueSettingsChanged?.call();
  }

  void _previewFontScale(double value) {
    setState(() => _fontScale = value);
  }

  Future<void> _commitFontScale(double value) async {
    final next = value.clamp(0.85, 1.25).toDouble();
    setState(() => _fontScale = next);
    await StorageService.saveFontScale(next);
    widget.onDisplaySettingsChanged();
  }

  Future<void> _confirmForfeitAndRestartLeague() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.warmSurface,
        title: Text(
          'Forfeit Current League?',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will end your current league and immediately start a new 4-week league from today. Competitor scores will reset.',
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
              'Forfeit & Restart',
              style: GoogleFonts.dmSans(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (shouldReset != true || !mounted) return;

    await widget.onLeagueReset();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'League restarted from today.',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Widget _buildThemePreviewSwatch() {
    final colors = AppColors.previewSwatch(_displayTheme);
    return Row(
      children: [
        Text(
          'Preview',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        ...colors.map(
          (color) => Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textSecondary.withValues(alpha: 0.25),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required bool isOpen,
    required ValueChanged<bool> onOpenChanged,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.golden.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        initiallyExpanded: isOpen,
        onExpansionChanged: onOpenChanged,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: AppColors.brown,
        collapsedIconColor: AppColors.brown,
        title: Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.deepBrown,
          ),
        ),
        children: [child],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionCard(
                  title: 'Display',
                  isOpen: _displaySectionOpen,
                  onOpenChanged: (v) =>
                      setState(() => _displaySectionOpen = v),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildThemePreviewSwatch(),
                      const SizedBox(height: 16),
                      Text(
                        'Color Theme',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppColors.displayThemeLabels.entries.map((e) {
                          final isSelected = e.key == _displayTheme;
                          return ChoiceChip(
                            label: Text(
                              e.value,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.deepBrown
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) => _setDisplayTheme(e.key),
                            selectedColor: AppColors.golden.withValues(
                              alpha: 0.55,
                            ),
                            backgroundColor: AppColors.warmSurface,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.amber
                                  : AppColors.golden.withValues(alpha: 0.35),
                            ),
                            showCheckmark: false,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Font Size',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Smaller to larger text across the app',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.amber,
                          inactiveTrackColor: AppColors.golden.withValues(
                            alpha: 0.3,
                          ),
                          thumbColor: AppColors.brown,
                          overlayColor: AppColors.amber.withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          min: 0.85,
                          max: 1.25,
                          divisions: 8,
                          value: _fontScale,
                          onChanged: _previewFontScale,
                          onChangeEnd: _commitFontScale,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${(_fontScale * 100).round()}%',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSectionCard(
                  title: 'Daily Prompts',
                  isOpen: _dailyPromptsSectionOpen,
                  onOpenChanged: (v) =>
                      setState(() => _dailyPromptsSectionOpen = v),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose which categories can appear in daily prompts. Changes apply immediately.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            '${_dailyPromptCategoryEnabled.values.where((v) => v).length}/${StorageService.promptCategories.length} enabled',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _enableAllPromptCategories,
                            child: Text(
                              'Enable all',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                color: AppColors.brown,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...StorageService.promptCategories.map((category) {
                        final enabled =
                            _dailyPromptCategoryEnabled[category] ?? true;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.golden.withValues(alpha: 0.3),
                            ),
                          ),
                          child: SwitchListTile.adaptive(
                            value: enabled,
                            onChanged: (value) =>
                                _setDailyPromptCategoryEnabled(category, value),
                            title: Text(
                              category,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            activeThumbColor: AppColors.brown,
                            activeTrackColor: AppColors.golden.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                _buildSectionCard(
                  title: 'League',
                  isOpen: _leagueSectionOpen,
                  onOpenChanged: (v) => setState(() => _leagueSectionOpen = v),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.golden.withValues(alpha: 0.3),
                          ),
                        ),
                        child: SwitchListTile.adaptive(
                          value: _dynamicLeagueDifficulty,
                          onChanged: _setDynamicLeagueDifficulty,
                          title: Text(
                            'Dynamic Difficulty',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'When enabled, competitor chances adapt to your recent activity.',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          activeThumbColor: AppColors.brown,
                          activeTrackColor: AppColors.golden.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.golden.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Difficulty Preset',
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Applies immediately and sets all competitors\' base probabilities.',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ('easy', 'Easy'),
                                ('medium', 'Medium'),
                                ('hard', 'Hard'),
                              ].map((entry) {
                                final key = entry.$1;
                                final label = entry.$2;
                                final selected = key == _leagueDifficultyPreset;
                                return ChoiceChip(
                                  label: Text(
                                    label,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? AppColors.deepBrown
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  selected: selected,
                                  onSelected: (_) => _setLeagueDifficultyPreset(key),
                                  selectedColor: AppColors.golden.withValues(
                                    alpha: 0.55,
                                  ),
                                  backgroundColor: AppColors.warmSurface,
                                  side: BorderSide(
                                    color: selected
                                        ? AppColors.amber
                                        : AppColors.golden.withValues(
                                            alpha: 0.35,
                                          ),
                                  ),
                                  showCheckmark: false,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.golden.withValues(alpha: 0.3),
                          ),
                        ),
                        child: SwitchListTile.adaptive(
                          value: _showIndividualProbabilitySelectors,
                          onChanged: _setShowIndividualProbabilitySelectors,
                          title: Text(
                            'Show Individual Base Probability Controls',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Turn off to hide base probability sliders when editing individual competitors.',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          activeThumbColor: AppColors.brown,
                          activeTrackColor: AppColors.golden.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'League Reset / Forfeit',
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ends your current league and starts a fresh 4-week league immediately.',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _confirmForfeitAndRestartLeague,
                                icon: const Icon(Icons.restart_alt),
                                label: Text(
                                  'Forfeit & Restart League',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

///
/// PROFILE SCREEN
