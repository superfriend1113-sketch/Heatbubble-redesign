import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';
import 'services/nudge_service.dart';
import 'services/background_service.dart';
import 'services/unit_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Load persisted temperature unit before first frame
  await UnitService.instance.load();

  // Initialize notifications
  await NudgeService.init();

  // Request notification permission (Android 13+)
  await Permission.notification.request();

  // Initialize background polling
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  initBackgroundPolling();

  runApp(const HeatBubbleApp());
}
