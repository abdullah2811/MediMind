import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/firebase_auth_environment.dart';
import 'core/localization/app_localization.dart';
import 'firebase_options.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'features/medication_reminder/data/datasources/medication_local_data_source.dart';
import 'features/medication_reminder/data/datasources/medication_remote_data_source.dart';
import 'features/medication_reminder/data/repositories/medication_repository_impl.dart';
import 'features/medication_reminder/data/services/medication_notification_service.dart';
import 'features/medication_reminder/data/services/medication_sync_service.dart';
import 'features/medication_reminder/domain/repositories/medication_repository.dart';

class MediMindApp extends StatefulWidget {
  const MediMindApp({super.key, this.repository, this.authRepository});

  final MedicationRepository? repository;
  final AuthRepository? authRepository;

  @override
  State<MediMindApp> createState() => _MediMindAppState();
}

class _MediMindAppState extends State<MediMindApp> {
  late final AppLanguageController _languageController;

  @override
  void initState() {
    super.initState();
    _languageController = AppLanguageController();
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = MedicationNotificationService();
    final medicationRepository =
        widget.repository ?? _buildDefaultRepository(notificationService);
    final authenticationRepository =
        widget.authRepository ?? _buildDefaultAuthRepository();

    return AppLanguageScope(
      controller: _languageController,
      child: ValueListenableBuilder<Locale>(
        valueListenable: _languageController,
        builder: (context, locale, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: context.tr('app_name'),
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('bn')],
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1C5D99),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              textTheme: const TextTheme(
                headlineMedium: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
                titleLarge: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                bodyLarge: TextStyle(fontSize: 18),
              ),
            ),
            home: AuthGate(
              authRepository: authenticationRepository,
              medicationRepository: medicationRepository,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  AuthRepository _buildDefaultAuthRepository() {
    return FirebaseAuthRepository(auth: FirebaseAuth.instance);
  }

  MedicationRepository _buildDefaultRepository(
    MedicationNotificationService notificationService,
  ) {
    final firestore = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;
    final localDataSource = MedicationLocalDataSource(boxName: 'medications');
    final remoteDataSource = MedicationRemoteDataSource(firestore: firestore);

    return MedicationRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      syncService: MedicationSyncService(
        firestore: firestore,
        storage: storage,
        localDataSource: localDataSource,
        remoteDataSource: remoteDataSource,
        notificationService: notificationService,
      ),
      notificationService: notificationService,
    );
  }
}

Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await configureFirebaseAuthForEnvironment(FirebaseAuth.instance);
  await Hive.initFlutter();
  await MedicationNotificationService().initialize();
  runApp(const MediMindApp());
}
