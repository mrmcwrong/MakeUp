part of '../main.dart';

// Shared avatar utilities

class AvatarSelectionResult {
  final String imagePath;
  final AvatarFrameShape frameShape;
  final bool showFrame;

  const AvatarSelectionResult({
    required this.imagePath,
    required this.frameShape,
    required this.showFrame,
  });
}

class _AvatarCropResult {
  final Uint8List imageBytes;
  final AvatarFrameShape frameShape;
  final bool showFrame;

  const _AvatarCropResult({
    required this.imageBytes,
    required this.frameShape,
    required this.showFrame,
  });
}

/// Picks an image and opens a crop/confirm screen where users can choose
/// circle/square framing and whether the frame outline is visible.
Future<AvatarSelectionResult?> pickAndConfigureAvatar(
  BuildContext context,
  ImageSource source, {
  AvatarFrameShape initialFrameShape = AvatarFrameShape.circle,
  bool initialShowFrame = false,
}) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    imageQuality: 95,
    maxWidth: 1600,
  );
  if (picked == null || !context.mounted) return null;

  final cropResult = await Navigator.of(context).push<_AvatarCropResult>(
    MaterialPageRoute(
      builder: (_) => _AvatarCropConfirmScreen(
        imagePath: picked.path,
        initialFrameShape: initialFrameShape,
        initialShowFrame: initialShowFrame,
      ),
    ),
  );

  if (cropResult == null) return null;

  final docsDir = await getApplicationDocumentsDirectory();
  final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.png';
  final outFile = File('${docsDir.path}/$fileName');
  await outFile.writeAsBytes(cropResult.imageBytes, flush: true);

  return AvatarSelectionResult(
    imagePath: outFile.path,
    frameShape: cropResult.frameShape,
    showFrame: cropResult.showFrame,
  );
}

/// Picks an image from [source], copies it permanently into the app's documents
/// directory, and returns the saved path. Returns null if the user cancels.
Future<String?> pickAndSaveAvatar(ImageSource source) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 512,
  );
  if (picked == null) return null;

  final docsDir = await getApplicationDocumentsDirectory();
  final fileName =
      'avatar_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
  final saved = await File(picked.path).copy('${docsDir.path}/$fileName');
  return saved.path;
}

class _AvatarCropConfirmScreen extends StatefulWidget {
  final String imagePath;
  final AvatarFrameShape initialFrameShape;
  final bool initialShowFrame;

  const _AvatarCropConfirmScreen({
    required this.imagePath,
    required this.initialFrameShape,
    required this.initialShowFrame,
  });

  @override
  State<_AvatarCropConfirmScreen> createState() =>
      _AvatarCropConfirmScreenState();
}

class _AvatarCropConfirmScreenState extends State<_AvatarCropConfirmScreen> {
  final CropController _cropController = CropController();
  Uint8List? _imageBytes;
  AvatarFrameShape _frameShape = AvatarFrameShape.circle;
  bool _showFrame = false;
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _frameShape = widget.initialFrameShape;
    _showFrame = widget.initialShowFrame;
    _loadBytes();
  }

  Future<void> _loadBytes() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
    });
  }

  void _confirmSelection() {
    setState(() => _isCropping = true);
    _cropController.crop();
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _imageBytes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Logo'),
      ),
      body: imageBytes == null
          ? Center(child: CircularProgressIndicator(color: AppColors.amber))
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Crop(
                        key: ValueKey(_frameShape),
                        image: imageBytes,
                        controller: _cropController,
                        withCircleUi: _frameShape == AvatarFrameShape.circle,
                        aspectRatio: 1,
                        interactive: true,
                        fixCropRect: true,
                        baseColor: AppColors.deepBrown.withValues(alpha: 0.9),
                        maskColor: Colors.black.withValues(alpha: 0.55),
                        radius: 18,
                        onCropped: (result) {
                          if (!mounted) return;
                          if (result is CropSuccess) {
                            Navigator.of(context).pop(
                              _AvatarCropResult(
                                imageBytes: result.croppedImage,
                                frameShape: _frameShape,
                                showFrame: _showFrame,
                              ),
                            );
                            return;
                          }

                          final error =
                              result is CropFailure ? result.cause : 'Unknown';
                          setState(() => _isCropping = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not crop image: $error',
                                style: GoogleFonts.dmSans(),
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warmSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.golden.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SegmentedButton<AvatarFrameShape>(
                                segments: const [
                                  ButtonSegment<AvatarFrameShape>(
                                    value: AvatarFrameShape.circle,
                                    icon: Icon(Icons.circle_outlined),
                                    label: Text('Circle'),
                                  ),
                                  ButtonSegment<AvatarFrameShape>(
                                    value: AvatarFrameShape.square,
                                    icon: Icon(Icons.crop_square),
                                    label: Text('Square'),
                                  ),
                                ],
                                selected: {_frameShape},
                                onSelectionChanged: (selection) {
                                  if (selection.isEmpty) return;
                                  setState(() {
                                    _frameShape = selection.first;
                                  });
                                },
                                showSelectedIcon: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Keep frame visible',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Off hides the border in the final logo',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          value: _showFrame,
                          onChanged: (value) {
                            setState(() => _showFrame = value);
                          },
                          activeTrackColor: AppColors.amber,
                          activeThumbColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCropping ? null : _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isCropping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Use This Logo',
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
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
    final fileName =
        'attach_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
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
  if (mime.contains('word') ||
      path.endsWith('.docx') ||
      path.endsWith('.doc')) {
    return Icons.description_outlined;
  }
  if (mime.contains('sheet') ||
      path.endsWith('.xlsx') ||
      path.endsWith('.csv')) {
    return Icons.table_chart_outlined;
  }
  if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
  return Icons.insert_drive_file_outlined;
}

/// Displays a circular avatar - photo if a path is set, otherwise an icon.
class AvatarWidget extends StatelessWidget {
  final String? imagePath;
  final double size;
  final bool isUser;
  final AvatarFrameShape frameShape;
  final bool showFrame;

  const AvatarWidget({
    super.key,
    required this.imagePath,
    this.size = 48,
    this.isUser = false,
    this.frameShape = AvatarFrameShape.circle,
    this.showFrame = false,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    Widget photoChild;
    if (path != null && path.startsWith('assets/')) {
      photoChild = Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.person, size: size * 0.5, color: AppColors.brown),
      );
    } else if (path != null) {
      photoChild = Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.person, size: size * 0.5, color: AppColors.brown),
      );
    } else {
      photoChild = Icon(Icons.person, size: size * 0.5, color: AppColors.brown);
    }

    final borderColor = isUser
        ? AppColors.golden.withValues(alpha: 0.4)
        : AppColors.golden.withValues(alpha: 0.2);
    final borderWidth = showFrame ? (isUser ? 2.5 : 1.5) : 0.0;
    final isCircle = frameShape == AvatarFrameShape.circle;
    final squareRadius = showFrame ? size * 0.14 : 0.0;

    final clippedPhoto = isCircle
        ? ClipOval(child: Center(child: photoChild))
        : ClipRRect(
            borderRadius: BorderRadius.circular(squareRadius),
            child: Center(child: photoChild),
          );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(squareRadius),
        color: showFrame
            ? (isUser ? AppColors.lightYellow : AppColors.warmSurface)
            : Colors.transparent,
        border: Border.all(
          color: showFrame ? borderColor : Colors.transparent,
          width: borderWidth,
        ),
      ),
      child: clippedPhoto,
    );
  }
}

// Attachment widgets

/// Editable attachment grid - used while composing a submission.
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                            child: Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.brown,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                fileIcon(path),
                                color: AppColors.brown,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
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
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.white,
                        ),
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

/// Read-only attachment grid - used when viewing past submissions.
/// - Images open in a full-screen in-app viewer (tap back arrow to return).
/// - Audio files show an in-app bottom sheet - swipe down or tap Close to dismiss.
/// - All other files (PDF, docs, etc.) open with the device's default app via OpenFilex.
class AttachmentsViewer extends StatelessWidget {
  final List<String> attachments;

  const AttachmentsViewer({super.key, required this.attachments});

  void _openFile(BuildContext context, String path) {
    final mime = lookupMimeType(path) ?? '';
    final exists = File(path).existsSync();
    if (!exists) return;

    if (mime.startsWith('image/')) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => _ImageViewerScreen(path: path)));
    } else if (mime.startsWith('audio/')) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.warmSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _AudioFileSheet(path: path),
      );
    } else {
      OpenFilex.open(path);
    }
  }

  Future<void> _downloadFile(BuildContext context, String path) async {
    final exists = File(path).existsSync();
    if (!exists) return;

    try {
      final name = p.basename(path);
      final cleanName = name.replaceFirst(RegExp(r'^attach_\d+_'), '');

      // Copy to a temp file with the clean name so the share sheet shows it correctly
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$cleanName');
      await File(path).copy(tempFile.path);

      await Share.shareXFiles([XFile(tempFile.path)], subject: cleanName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share file', style: GoogleFonts.dmSans()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

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
            final name = p.basename(path);
            final isImg = isImageFile(path);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // File tile
                GestureDetector(
                  onTap: () => _openFile(context, path),
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
                    child: isImg
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.brown,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                fileIcon(path),
                                color: AppColors.brown,
                                size: 26,
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
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
                ),

                // Download button (bottom-right corner)
                Positioned(
                  bottom: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => _downloadFile(context, path),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.brown,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.download,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Full-screen image viewer with a back button and pinch-to-zoom.
class _ImageViewerScreen extends StatelessWidget {
  final String path;
  const _ImageViewerScreen({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          p.basename(path),
          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.file(File(path), fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Bottom sheet with a built-in audio player.
/// Plays the file entirely inside the app - no external app is launched.
/// Swipe down, tap outside, or tap the x button to dismiss.
class _AudioFileSheet extends StatefulWidget {
  final String path;
  const _AudioFileSheet({required this.path});

  @override
  State<_AudioFileSheet> createState() => _AudioFileSheetState();
}

class _AudioFileSheetState extends State<_AudioFileSheet> {
  late final AudioPlayer _player;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _subs.addAll([
      _player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _state = s);
      }),
      _player.onPositionChanged.listen((pos) {
        if (mounted) setState(() => _position = pos);
      }),
      _player.onDurationChanged.listen((dur) {
        if (mounted) setState(() => _duration = dur);
      }),
    ]);
    // Auto-play when sheet opens
    _player.play(DeviceFileSource(widget.path));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final name = p.basename(widget.path);
    final isPlaying = _state == PlayerState.playing;
    final total = _duration.inSeconds > 0
        ? _duration.inSeconds.toDouble()
        : 1.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle + close button row
          Row(
            children: [
              const Spacer(),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.golden.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.warmSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.golden.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Album art placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.lightYellow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.golden.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Icon(Icons.audiotrack, color: AppColors.brown, size: 38),
          ),
          const SizedBox(height: 14),

          // File name
          Text(
            name,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          // Seek bar
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppColors.brown,
              inactiveTrackColor: AppColors.golden.withValues(alpha: 0.2),
              thumbColor: AppColors.brown,
              overlayColor: AppColors.brown.withValues(alpha: 0.15),
            ),
            child: Slider(
              min: 0,
              max: total,
              value: _position.inSeconds.toDouble().clamp(0, total),
              onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
            ),
          ),

          // Time labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmt(_position),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  _fmt(_duration),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rewind 10s
              IconButton(
                icon: const Icon(Icons.replay_10),
                color: AppColors.brown,
                iconSize: 32,
                onPressed: () => _player.seek(
                  Duration(
                    seconds: (_position.inSeconds - 10).clamp(
                      0,
                      _duration.inSeconds,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Play / Pause
              GestureDetector(
                onTap: () {
                  if (isPlaying) {
                    _player.pause();
                  } else {
                    _player.play(DeviceFileSource(widget.path));
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.brown,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brown.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Forward 10s
              IconButton(
                icon: const Icon(Icons.forward_10),
                color: AppColors.brown,
                iconSize: 32,
                onPressed: () => _player.seek(
                  Duration(
                    seconds: (_position.inSeconds + 10).clamp(
                      0,
                      _duration.inSeconds,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

int calculateSubmissionStreak(List<Submission> submissions) {
  final streakEligible = submissions
      .where((s) => s.promptIndex >= 0 || s.points > 0)
      .toList();

  if (streakEligible.isEmpty) return 0;

  final uniqueDays = streakEligible
      .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
      .toSet()
      .toList()
    ..sort();

  var streak = 1;
  var cursor = uniqueDays.last;

  for (var i = uniqueDays.length - 2; i >= 0; i--) {
    final expectedPrev = cursor.subtract(const Duration(days: 1));
    if (uniqueDays[i] == expectedPrev) {
      streak++;
      cursor = uniqueDays[i];
    } else {
      break;
    }
  }

  return streak;
}

Widget buildStreakLeading(User user) {
  final streak = calculateSubmissionStreak(user.submissions);

  return Padding(
    padding: const EdgeInsets.only(left: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warmSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.golden.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.whatshot_rounded, size: 14, color: AppColors.deepBrown),
            const SizedBox(width: 4),
            Text(
              '$streak',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.deepBrown,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
