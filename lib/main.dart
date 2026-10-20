import 'package:flutter/material.dart';
import 'app/app.dart';
import 'services/app_data_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDataService.instance.initialize();
  await NotificationService.instance.initialize();
  runApp(const MyApp());
}

