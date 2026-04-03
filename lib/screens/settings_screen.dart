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
  List<String> _promptCategories = [];
  Map<String, List<String>> _promptCategoryGroups = {};
  final Set<String> _openPromptGroups = {};
  Map<String, bool> _dailyPromptCategoryEnabled = {};
  bool _dailyPromptSettingsDirty = false;

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
    final promptCategories = await StorageService.loadPromptCategories();
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
      _promptCategories = promptCategories;
      _promptCategoryGroups = _buildPromptCategoryGroups(promptCategories);
      _dailyPromptCategoryEnabled = dailyPromptCategoryEnabled;
      _isLoading = false;
    });
  }

  Map<String, List<String>> _buildPromptCategoryGroups(
    List<String> categories,
  ) {
    String groupFor(String category) {
      final c = category.toLowerCase();
      if (c.contains('design') ||
          c.contains('visual') ||
          c.contains('drawing') ||
          c.contains('painting') ||
          c.contains('illustrat') ||
          c.contains('typography') ||
          c.contains('logo') ||
          c.contains('color') ||
          c.contains('photo') ||
          c.contains('film') ||
          c.contains('video') ||
          c.contains('animation') ||
          c.contains('pixel')) {
        return 'Visual & Media';
      }

      if (c.contains('writing') ||
          c.contains('poetry') ||
          c.contains('story') ||
          c.contains('fiction') ||
          c.contains('essay') ||
          c.contains('journal') ||
          c.contains('screenwriting') ||
          c.contains('playwriting') ||
          c.contains('copy') ||
          c.contains('speech') ||
          c.contains('newsletter')) {
        return 'Writing & Narrative';
      }

      if (c.contains('music') ||
          c.contains('audio') ||
          c.contains('sound') ||
          c.contains('beat') ||
          c.contains('song') ||
          c.contains('lyrics') ||
          c.contains('jingle') ||
          c.contains('voice') ||
          c.contains('drum') ||
          c.contains('rhythm')) {
        return 'Music & Audio';
      }

      if (c.contains('theater') ||
          c.contains('choreography') ||
          c.contains('dance') ||
          c.contains('performance') ||
          c.contains('improvis') ||
          c.contains('acting') ||
          c.contains('stage')) {
        return 'Performance & Movement';
      }

      if (c.contains('craft') ||
          c.contains('knitting') ||
          c.contains('sewing') ||
          c.contains('textile') ||
          c.contains('wood') ||
          c.contains('ceramic') ||
          c.contains('sculpt') ||
          c.contains('origami') ||
          c.contains('model') ||
          c.contains('diorama') ||
          c.contains('embroidery') ||
          c.contains('makeup') ||
          c.contains('baking') ||
          c.contains('cooking') ||
          c.contains('floral')) {
        return 'Craft & Hands-On';
      }

      if (c.contains('code') ||
          c.contains('app') ||
          c.contains('ux') ||
          c.contains('ui') ||
          c.contains('algorithm') ||
          c.contains('machine learning') ||
          c.contains('robotics') ||
          c.contains('computing') ||
          c.contains('web') ||
          c.contains('ar') ||
          c.contains('vr') ||
          c.contains('open source')) {
        return 'Tech & Interactive';
      }

      if (c.contains('system') ||
          c.contains('strategy') ||
          c.contains('problem') ||
          c.contains('research') ||
          c.contains('policy') ||
          c.contains('mapping') ||
          c.contains('data') ||
          c.contains('planning') ||
          c.contains('negotiation') ||
          c.contains('presentation') ||
          c.contains('product')) {
        return 'Strategy & Systems';
      }

      if (c.contains('teaching') ||
          c.contains('learning') ||
          c.contains('journalism') ||
          c.contains('science') ||
          c.contains('history') ||
          c.contains('anthropology') ||
          c.contains('math') ||
          c.contains('communication')) {
        return 'Learning & Communication';
      }

      return 'Everyday Creativity';
    }

    final grouped = <String, List<String>>{};
    for (final category in categories) {
      final group = groupFor(category);
      grouped.putIfAbsent(group, () => <String>[]).add(category);
    }

    for (final entry in grouped.entries) {
      entry.value.sort();
    }

    final orderedKeys = grouped.keys.toList()..sort();
    return {
      for (final key in orderedKeys) key: grouped[key]!,
    };
  }

  Future<void> _setDailyPromptCategoryEnabled(
    String category,
    bool enabled,
  ) async {
    setState(() {
      _dailyPromptCategoryEnabled[category] = enabled;
      _dailyPromptSettingsDirty = true;
    });
  }

  Future<void> _setAllPromptCategories(bool enabled) async {
    setState(() {
      for (final category in _promptCategories) {
        _dailyPromptCategoryEnabled[category] = enabled;
      }
      _dailyPromptSettingsDirty = true;
    });
  }

  Future<void> _setPromptGroupEnabled(String group, bool enabled) async {
    final categories = _promptCategoryGroups[group] ?? const <String>[];
    if (categories.isEmpty) return;

    setState(() {
      for (final category in categories) {
        _dailyPromptCategoryEnabled[category] = enabled;
      }
      _dailyPromptSettingsDirty = true;
    });
  }

  Future<void> _applyDailyPromptSettingsOnExit() async {
    if (!_dailyPromptSettingsDirty) return;

    await StorageService.saveDailyPromptCategorySettings(
      _dailyPromptCategoryEnabled,
    );
    await StorageService.reconcileDailyPromptsAfterCategorySettingsChange();
    await widget.onDailyPromptSettingsChanged?.call();
    _dailyPromptSettingsDirty = false;
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
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        _applyDailyPromptSettingsOnExit();
      },
      child: Scaffold(
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
                    onOpenChanged: (v) => setState(() => _displaySectionOpen = v),
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
                              selectedColor: AppColors.golden.withValues(alpha: 0.55),
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
                            inactiveTrackColor: AppColors.golden.withValues(alpha: 0.3),
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
                    onOpenChanged: (v) => setState(() => _dailyPromptsSectionOpen = v),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose which categories can appear in daily prompts.',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            Builder(
                              builder: (context) {
                                final allEnabled = _promptCategories.every(
                                  (c) => _dailyPromptCategoryEnabled[c] ?? true,
                                );
                                return Tooltip(
                                  message: allEnabled
                                      ? 'Disable all categories'
                                      : 'Enable all categories',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _setAllPromptCategories(!allEnabled),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.golden.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Icon(
                                        allEnabled
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank,
                                        color: AppColors.brown,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'All',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ..._promptCategoryGroups.entries.map((entry) {
                          final group = entry.key;
                          final categories = entry.value;
                          final isOpen = _openPromptGroups.contains(group);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.golden.withValues(alpha: 0.3),
                              ),
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: isOpen,
                              onExpansionChanged: (open) {
                                setState(() {
                                  if (open) {
                                    _openPromptGroups.add(group);
                                  } else {
                                    _openPromptGroups.remove(group);
                                  }
                                });
                              },
                              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              title: Text(
                                group,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              children: [
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => _setPromptGroupEnabled(group, true),
                                      child: Text(
                                        'Enable group',
                                        style: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.brown,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton(
                                      onPressed: () => _setPromptGroupEnabled(group, false),
                                      child: Text(
                                        'Disable group',
                                        style: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                ...categories.map((category) {
                                  final enabled = _dailyPromptCategoryEnabled[category] ?? true;
                                  return SwitchListTile.adaptive(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value: enabled,
                                    onChanged: (value) => _setDailyPromptCategoryEnabled(
                                      category,
                                      value,
                                    ),
                                    title: Text(
                                      category,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    activeThumbColor: AppColors.brown,
                                    activeTrackColor: AppColors.golden.withValues(alpha: 0.5),
                                  );
                                }),
                              ],
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
                            activeTrackColor: AppColors.golden.withValues(alpha: 0.5),
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
                                    selectedColor: AppColors.golden.withValues(alpha: 0.55),
                                    backgroundColor: AppColors.warmSurface,
                                    side: BorderSide(
                                      color: selected
                                          ? AppColors.amber
                                          : AppColors.golden.withValues(alpha: 0.35),
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
                            activeTrackColor: AppColors.golden.withValues(alpha: 0.5),
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
                                    padding: const EdgeInsets.symmetric(vertical: 14),
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
      ),
    );
  }
}

///
/// PROFILE SCREEN
