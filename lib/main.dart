import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:mime/mime.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'debug_overlay.dart';
import 'debug_time.dart';

part 'core/theme.dart';
part 'models/models.dart';
part 'services/storage_service.dart';
part 'core/date_format.dart';
part 'app/app_shell.dart';
part 'screens/home_screen.dart';
part 'screens/weekly_task_screen.dart';
part 'screens/league_screen.dart';
part 'screens/settings_screen.dart';
part 'screens/profile_screen.dart';
part 'shared/media_widgets.dart';

void main() {
  runApp(const MyApp());
}
