import 'package:flutter/material.dart';
import 'app/app.dart';
import 'services/app_data_service.dart';
import 'services/notification_service.dart';
import 'services/pdf_storage_service.dart';
import 'services/vault_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDataService.instance.initialize();
  await NotificationService.instance.initialize();
  await PdfStorageService.instance.initialize();
  await VaultService.instance.initialize();
  runApp(const MyApp());
}

