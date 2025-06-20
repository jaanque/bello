import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // Use 'as p'
import 'video_player_screen.dart';
import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:share_plus/share_plus.dart';
import './recap_model.dart';
import './notification_service.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Import flutter_animate

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _currentMonth = DateTime.now();
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false;
  String? _videoPath;
  List<String> _videoFiles = [];
  bool _hasRecordedToday = false;
  String _recordButtonText = "Grabar video de hoy";
  bool _isRecordButtonEnabled = true;
  Timer? _recordingTimer;
  Timer? _countdownTimer; // For record button countdown
  String _recordButtonCountdownText = ""; // For record button countdown text

  List<Recap> _weeklyRecaps = [];
  List<Recap> _monthlyRecaps = [];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadMediaFromStorage();
    if (mounted) {
      await _generateWeeklyRecap();
      await _generateMonthlyRecap();
    }
    if (mounted) {
      await _initCamerasAndButton(); // This will call _updateRecordButtonState
    }

    if (mounted && !_hasRecordedToday) {
      await NotificationService.scheduleDailyReminderNotification();
    } else if (mounted && _hasRecordedToday) {
      await NotificationService.cancelDailyReminderNotification();
    }

    if (mounted) {
      setState(() {}); // General UI refresh after all async ops
    }
  }

  Future<void> _loadMediaFromStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> entities = directory.listSync();

      final List<String> loadedVideoPaths = [];
      final List<Recap> loadedWeeklyRecaps = [];
      final List<Recap> loadedMonthlyRecaps = [];
      final String todayDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      bool foundVideoForToday = false;

      final RegExp videoFilePattern = RegExp(r'^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.mp4$');
      final RegExp recapWeekPattern = RegExp(r'^recap_week_(\d{4})-(\d{2})\.mp4$');
      final RegExp recapMonthPattern = RegExp(r'^recap_(\d{4})-(\d{2})\.mp4$');

      for (var entity in entities) {
        if (entity is File && p.extension(entity.path) == '.mp4') {
          final fileName = p.basename(entity.path);

          if (videoFilePattern.hasMatch(fileName)) {
            loadedVideoPaths.add(entity.path);
            if (fileName.startsWith(todayDateStr)) {
              foundVideoForToday = true;
            }
          } else if (recapWeekPattern.hasMatch(fileName)) {
            final match = recapWeekPattern.firstMatch(fileName)!;
            final year = int.parse(match.group(1)!);
            final week = int.parse(match.group(2)!);
            loadedWeeklyRecaps.add(Recap(
              id: fileName, title: 'Recap Semana $week, $year', filePath: entity.path,
              type: RecapType.weekly, dateGenerated: _getDateFromYearAndWeek(year, week),
            ));
          } else if (recapMonthPattern.hasMatch(fileName)) {
            final match = recapMonthPattern.firstMatch(fileName)!;
            final year = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            loadedMonthlyRecaps.add(Recap(
              id: fileName, title: 'Recap ${DateFormat('MMMM yyyy').format(DateTime(year, month))}',
              filePath: entity.path, type: RecapType.monthly, dateGenerated: DateTime(year, month, 1),
            ));
          }
        }
      }

      loadedVideoPaths.sort((a, b) => p.basename(b).compareTo(p.basename(a)));
      loadedWeeklyRecaps.sort((a, b) => b.dateGenerated.compareTo(a.dateGenerated));
      loadedMonthlyRecaps.sort((a, b) => b.dateGenerated.compareTo(a.dateGenerated));

      if(mounted){
        setState(() {
          _videoFiles = loadedVideoPaths;
          _weeklyRecaps = loadedWeeklyRecaps;
          _monthlyRecaps = loadedMonthlyRecaps;
          _hasRecordedToday = foundVideoForToday;
        });
      }
    } catch (e) {
      print('Error loading media from storage: $e');
    }
  }

  DateTime _getDateFromYearAndWeek(int year, int week) {
    final jan4 = DateTime(year, 1, 4);
    final dayOfWeekJan4 = jan4.weekday;
    final firstMondayOfWeek1 = jan4.subtract(Duration(days: dayOfWeekJan4 - 1));
    return firstMondayOfWeek1.add(Duration(days: (week - 1) * 7));
  }

  Future<void> _initCamerasAndButton() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _cameraController = CameraController(_cameras[0], ResolutionPreset.medium, enableAudio: true);
        await _cameraController!.initialize();
      } else {
        print("No cameras available");
      }
    } on CameraException catch (e) {
      print('Error initializing camera: ${e.code} ${e.description}');
    }
    _updateRecordButtonState(); // This will now handle countdown if needed
    if (mounted) {
      setState(() {});
    }
  }

  void _updateRecordButtonState() {
    _countdownTimer?.cancel();

    if (_hasRecordedToday) {
      _isRecordButtonEnabled = false;

      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1); // Midnight
      Duration timeUntilTomorrow = tomorrow.difference(now);

      void updateCountdown() {
        timeUntilTomorrow = tomorrow.difference(DateTime.now());
        if (timeUntilTomorrow.isNegative || timeUntilTomorrow.inSeconds < 1) {
          _countdownTimer?.cancel();
          if (mounted) {
            setState(() {
              _hasRecordedToday = false; // New day, allow recording
            });
            _updateRecordButtonState(); // Re-run to set to "Grabar video de hoy"
          }
          return;
        }
        final hours = timeUntilTomorrow.inHours;
        final minutes = timeUntilTomorrow.inMinutes.remainder(60);

        if (mounted) {
          setState(() {
            _recordButtonCountdownText = "${hours}h ${minutes}m";
            _recordButtonText = "Disponible en $_recordButtonCountdownText";
          });
        }
      }

      updateCountdown();
      _countdownTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        updateCountdown();
      });

    } else {
      _isRecordButtonEnabled = _cameraController != null && _cameraController!.value.isInitialized;
      _recordButtonText = _isRecording ? "Detener grabación" : "Grabar video de hoy";
      if (mounted) setState((){});
    }
  }

  Future<String> _generateVideoPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final String timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    return p.join(directory.path, '$timestamp.mp4');
  }

  Future<void> _onRecordButtonPressed() async {
    if (!_isRecordButtonEnabled || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_cameraController!.value.isRecordingVideo) {
      _recordingTimer?.cancel();
      try {
        final XFile videoFile = await _cameraController!.stopVideoRecording();
        if (mounted) {
          setState(() {
            _videoPath = videoFile.path;
            _videoFiles.add(videoFile.path);
            _videoFiles.sort((a, b) => p.basename(b).compareTo(p.basename(a)));
            _hasRecordedToday = true;
            _isRecording = false;
          });
          if (_hasRecordedToday) {
            await NotificationService.cancelDailyReminderNotification();
          }
        }
      } on CameraException catch (e) {
        print('Error stopping video recording: $e');
      }
    } else {
      try {
        await _cameraController!.startVideoRecording();
         if (mounted) {
            setState(() { _isRecording = true; });
         }
        _recordingTimer = Timer(const Duration(seconds: 10), () {
          if (_cameraController != null && _cameraController!.value.isRecordingVideo) {
            _onRecordButtonPressed();
          }
        });
      } on CameraException catch (e) {
        print('Error starting video recording: $e');
        if (mounted) { setState(() { _isRecording = false; }); }
      }
    }
    _updateRecordButtonState();
  }

  bool _needsWeeklyRecapGeneration() {
    final now = DateTime.now();
    if (now.weekday != DateTime.monday) return false;
    final lastWeekMonday = now.subtract(Duration(days: now.weekday -1 + 7));
    final year = lastWeekMonday.year;
    final dayOfYear = int.parse(DateFormat("D").format(lastWeekMonday));
    final weekNumber = ((dayOfYear - lastWeekMonday.weekday + 10) / 7).floor();
    final expectedRecapId = 'recap_week_${year}-${weekNumber.toString().padLeft(2, '0')}.mp4';
    return !_weeklyRecaps.any((recap) => recap.id == expectedRecapId);
  }

  Future<void> _generateWeeklyRecap() async {
    if (!mounted || !_needsWeeklyRecapGeneration()) return;
    print("Attempting to generate weekly recap...");
    final now = DateTime.now();
    final currentWeekMonday = now.subtract(Duration(days: now.weekday - 1));
    final lastWeekEnd = currentWeekMonday.subtract(const Duration(days: 1));
    final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
    final videosForRecap = _videoFiles.where((filePath) {
      try {
        final fileName = p.basename(filePath);
        final datePart = fileName.split('_').first;
        final videoDate = DateFormat('yyyy-MM-dd').parse(datePart);
        return !videoDate.isBefore(lastWeekStart) && !videoDate.isAfter(lastWeekEnd);
      } catch (e) { return false; }
    }).toList();
    videosForRecap.sort((a, b) => p.basename(a).compareTo(p.basename(b)));
    if (videosForRecap.length < 2) {
      print('Not enough videos for weekly recap. Found ${videosForRecap.length}');
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final inputsFilePath = p.join(directory.path, 'weekly_inputs.txt');
    final inputsFile = File(inputsFilePath);
    try {
      await inputsFile.writeAsString(videosForRecap.map((path) => "file '${path}'").join('
'));
    } catch (e) { print("Error writing inputs file for weekly recap: $e"); return; }
    final year = lastWeekStart.year;
    final dayOfYear = int.parse(DateFormat("D").format(lastWeekStart));
    final weekNumber = ((dayOfYear - lastWeekStart.weekday + 10) / 7).floor();
    final recapFileName = 'recap_week_${year}-${weekNumber.toString().padLeft(2, '0')}.mp4';
    final recapFilePath = p.join(directory.path, recapFileName);
    if (await File(recapFilePath).exists()) {
      print('Weekly recap $recapFileName already exists. Skipping.');
      if (await inputsFile.exists()) await inputsFile.delete();
      if (!_weeklyRecaps.any((r) => r.id == recapFileName) && mounted) {
         final newRecap = Recap(id: recapFileName, title: 'Recap Semana $weekNumber, $year', filePath: recapFilePath, type: RecapType.weekly, dateGenerated: _getDateFromYearAndWeek(year, weekNumber));
         setState(() { _weeklyRecaps.add(newRecap); _weeklyRecaps.sort((a, b) => b.dateGenerated.compareTo(a.dateGenerated)); });
      } return;
    }
    final command = "-y -f concat -safe 0 -i "${inputsFile.path}" -c copy "$recapFilePath"";
    print('Executing FFmpeg for weekly recap: $command');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      print('Weekly recap generated: $recapFilePath');
      final newRecap = Recap(id: recapFileName, title: 'Recap Semana $weekNumber, $year', filePath: recapFilePath, type: RecapType.weekly, dateGenerated: _getDateFromYearAndWeek(year, weekNumber));
      if (mounted) { setState(() { _weeklyRecaps.add(newRecap); _weeklyRecaps.sort((a, b) => b.dateGenerated.compareTo(a.dateGenerated)); }); }
    } else { print('Error generating weekly recap. RC: $returnCode'); /* ... logs ... */ }
    if (await inputsFile.exists()) await inputsFile.delete();
  }

  bool _needsMonthlyRecapGeneration() {
    final now = DateTime.now();
    if (now.day != 1) return false;
    final previousMonthDateTime = DateTime(now.year, now.month - 1, 1);
    final year = previousMonthDateTime.year;
    final month = previousMonthDateTime.month;
    final expectedRecapId = 'recap_${year}-${month.toString().padLeft(2, '0')}.mp4';
    return !_monthlyRecaps.any((recap) => recap.id == expectedRecapId);
  }

  Future<void> _generateMonthlyRecap() async {
    if (!mounted || !_needsMonthlyRecapGeneration()) return;
    print("Attempting to generate monthly recap...");
    final now = DateTime.now();
    final previousMonthEnd = DateTime(now.year, now.month, 0);
    final previousMonthStart = DateTime(previousMonthEnd.year, previousMonthEnd.month, 1);
    final videosForRecap = _videoFiles.where((filePath) {
      try {
        final fileName = p.basename(filePath);
        final datePart = fileName.split('_').first;
        final videoDate = DateFormat('yyyy-MM-dd').parse(datePart);
        return !videoDate.isBefore(previousMonthStart) && !videoDate.isAfter(previousMonthEnd);
      } catch (e) { return false; }
    }).toList();
    videosForRecap.sort((a, b) => p.basename(a).compareTo(p.basename(b)));
    if (videosForRecap.length < 2) {
      print('Not enough videos for monthly recap. Found ${videosForRecap.length}');
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final inputsFilePath = p.join(directory.path, 'monthly_inputs.txt');
    final inputsFile = File(inputsFilePath);
    try {
      await inputsFile.writeAsString(videosForRecap.map((path) => "file '${path}'").join('
'));
    } catch (e) { print("Error writing inputs file for monthly recap: $e"); return; }
    final year = previousMonthStart.year;
    final month = previousMonthStart.month;
    final recapFileName = 'recap_${year}-${month.toString().padLeft(2, '0')}.mp4';
    final recapFilePath = p.join(directory.path, recapFileName);
    if (await File(recapFilePath).exists()) {
      print('Monthly recap $recapFileName already exists. Skipping.');
      if (await inputsFile.exists()) await inputsFile.delete();
      if (!_monthlyRecaps.any((r) => r.id == recapFileName) && mounted) {
        final newRecap = Recap(id: recapFileName, title: 'Recap ${DateFormat('MMMM yyyy').format(DateTime(year, month))}', filePath: recapFilePath, type: RecapType.monthly, dateGenerated: DateTime(year, month, 1));
        setState(() { _monthlyRecaps.add(newRecap); _monthlyRecaps.sort((a, b) => b.dateGenerated.compareTo(a.dateGenerated)); });
      } return;
    }
    final command = "-y -f concat -safe 0 -i "${inputsFile.path}" -c copy "$recapFilePath"";
    print('Executing FFmpeg for monthly recap: $command');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      print('Monthly recap generated: $recapFilePath');
      final newRecap = Recap(id: recapFileName, title: 'Recap ${DateFormat('MMMM yyyy').format(DateTime(year, month))}', filePath: recapFilePath, type: RecapType.monthly, dateGenerated: DateTime(year, month, 1));
      if (mounted) { setState(() { _monthlyRecaps.add(newRecap); _monthlyRecaps.sort((a, b) => b.dateGenerated.compareTo(a.dateGenerated)); }); }
    } else { print('Error generating monthly recap. RC: $returnCode'); /* ... logs ... */ }
    if (await inputsFile.exists()) await inputsFile.delete();
  }

  Future<void> _deleteVideo(String filePath) async {
    if (p.basename(filePath).startsWith('recap_')) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Los videos de Recaps no se pueden eliminar.")));
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (BuildContext context) => AlertDialog(
      title: const Text('Delete Video'), content: const Text('Are you sure you want to delete this video? This action cannot be undone.'),
      actions: <Widget>[ TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')), ],));
    if (confirmed == true) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          if (mounted) {
            final String todayDateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
            bool stillHasVideoForTodayAfterDeletion = false;
            setState(() { _videoFiles.remove(filePath); stillHasVideoForTodayAfterDeletion = _videoFiles.any((path) => p.basename(path).startsWith(todayDateString)); _hasRecordedToday = stillHasVideoForTodayAfterDeletion; });
            _updateRecordButtonState(); // After _hasRecordedToday is updated
            if (!_hasRecordedToday) await NotificationService.scheduleDailyReminderNotification(); // Reschedule if needed
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video eliminado: ${p.basename(filePath)}')));
          }
        } else {
          if(mounted){
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File not found on disk, removing from list.')));
            setState(() { _videoFiles.remove(filePath); final String todayDateString = DateFormat('yyyy-MM-dd').format(DateTime.now()); _hasRecordedToday = _videoFiles.any((path) => p.basename(path).startsWith(todayDateString)); });
            _updateRecordButtonState();
            if (!_hasRecordedToday) await NotificationService.scheduleDailyReminderNotification();
          }
        }
      } catch (e) { print('Error deleting video: $e'); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting video: $e'))); }
    }
  }

  void _previousMonth() { setState(() { _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1); }); }
  void _nextMonth() { setState(() { _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1); }); }

  @override
  void dispose() {
    _cameraController?.dispose();
    _recordingTimer?.cancel();
    _countdownTimer?.cancel(); // Dispose countdown timer
    super.dispose();
  }

  Widget _buildRecapBanner(Recap recap) {
    Color bannerColor = recap.type == RecapType.weekly ? const Color(0xFFE6E6FA) : const Color(0xFFFFFACD);
    String shareMessage = recap.type == RecapType.weekly ? "¡Mira mi recap semanal de Bello!" : "¡Mira mi recap mensual de Bello!";
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bannerColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 2))]),
      child: Row(children: [ Expanded(child: Text(recap.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800]))),
          IconButton(icon: Icon(Icons.play_circle_outline, color: Colors.grey[700]), iconSize: 28, tooltip: 'Reproducir', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerScreen(filePath: recap.filePath)))),
          IconButton(icon: Icon(Icons.share_outlined, color: Colors.grey[700]), iconSize: 28, tooltip: 'Compartir', onPressed: () async { try { await Share.shareXFiles([XFile(recap.filePath)], text: '$shareMessage ${recap.title}'); } catch (e) { print('Error sharing recap: $e'); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al compartir: $e'))); }})
      ])).animate().fadeIn(duration: 500.ms); // Added animation
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bello')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: _previousMonth), Text(DateFormat('MMMM yyyy').format(_currentMonth), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: _nextMonth) ])),
        if (_monthlyRecaps.isEmpty && _weeklyRecaps.isEmpty && _videoFiles.isEmpty) // Check if all lists are empty for general message
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0), // Add some padding
              child: Center(child: Text('Comienza grabando tu primer video.', style: TextStyle(fontSize: 16, color: Colors.grey[600])))
            )
        else ...[ // Use spread operator if there's at least one recap or video
            if (_monthlyRecaps.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8.0, bottom: 4.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _monthlyRecaps.map((recap) => _buildRecapBanner(recap)).toList())),
            if (_weeklyRecaps.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4.0, bottom: 4.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _weeklyRecaps.map((recap) => _buildRecapBanner(recap)).toList())),
        ],
        Expanded(
          child: _videoFiles.isEmpty && (_monthlyRecaps.isNotEmpty || _weeklyRecaps.isNotEmpty) // Show only if recaps exist but no daily videos for the month
              ? Center(child: Text('No hay videos grabados para este mes.', style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center))
              : GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8.0, mainAxisSpacing: 8.0, childAspectRatio: 1.0),
                  itemCount: _videoFiles.length,
                  itemBuilder: (context, index) {
                    final videoPath = _videoFiles[index];
                    return GestureDetector(
                      onTap: () { if (videoPath.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerScreen(filePath: videoPath))); },
                      onLongPress: () { _deleteVideo(videoPath); },
                      child: Container(
                        decoration: BoxDecoration(color: Colors.blueGrey[100], borderRadius: BorderRadius.circular(8.0), border: Border.all(color: Colors.blueGrey[300]!)),
                        child: Stack(alignment: Alignment.center, children: [ const Icon(Icons.videocam, color: Colors.white, size: 40),
                            Positioned(bottom: 4, left: 4, right: 4, child: Text(p.basename(videoPath).split('_').first, style: const TextStyle(color: Colors.black54, fontSize: 10), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                            Positioned(top: 4, right: 4, child: Icon(Icons.delete_forever, color: Colors.black26, size: 16))
                        ]))).animate().fadeIn(duration: 500.ms); // Added animation
                  })),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _isRecordButtonEnabled ? Theme.of(context).primaryColor : Colors.grey[400], padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), textStyle: const TextStyle(fontSize: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
            onPressed: _isRecordButtonEnabled ? _onRecordButtonPressed : null,
            child: Text(_recordButtonText, style: const TextStyle(color: Colors.white))))]));
  }
}
