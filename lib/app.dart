import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/firebase_auth_environment.dart';
import 'core/localization/app_localization.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_licenses.dart';
import 'firebase_options.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/auth/data/session_activity_store.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'features/medication_reminder/data/datasources/medication_local_data_source.dart';
import 'features/medication_reminder/data/datasources/medication_remote_data_source.dart';
import 'features/medication_reminder/data/repositories/medication_repository_impl.dart';
import 'features/medication_reminder/data/services/medication_notification_service.dart';
import 'features/medication_reminder/data/services/medication_sync_service.dart';
import 'features/medication_reminder/domain/repositories/medication_repository.dart';

class MediMindApp extends StatefulWidget {
  const MediMindApp({
    super.key,
    this.repository,
    this.authRepository,
    this.sessionActivityStore,
  });

  final MedicationRepository? repository;
  final AuthRepository? authRepository;
  final SessionActivityStore? sessionActivityStore;

  @override
  State<MediMindApp> createState() => _MediMindAppState();
}

class _MediMindAppState extends State<MediMindApp> {
  late final AppLanguageController _languageController;
  late final MedicationRepository _medicationRepository;
  late final AuthRepository _authenticationRepository;
  late final SessionActivityStore _sessionActivityStore;

  @override
  void initState() {
    super.initState();
    _languageController = AppLanguageController();
    final notificationService = MedicationNotificationService();
    _medicationRepository =
        widget.repository ?? _buildDefaultRepository(notificationService);
    _authenticationRepository =
        widget.authRepository ?? _buildDefaultAuthRepository();
    _sessionActivityStore =
        widget.sessionActivityStore ?? HiveSessionActivityStore();
  }

  @override
  Widget build(BuildContext context) {
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
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: buildAppTheme(locale),
            home: AuthGate(
              authRepository: _authenticationRepository,
              medicationRepository: _medicationRepository,
              sessionActivityStore: _sessionActivityStore,
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
      syncService: MedicationSyncService(
        firestore: firestore,
        storage: storage,
        localDataSource: localDataSource,
        remoteDataSource: remoteDataSource,
      ),
      notificationService: notificationService,
      connectivity: Connectivity(),
    );
  }
}

Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAppLicenses();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await configureFirebaseAuthForEnvironment(FirebaseAuth.instance);
  await Hive.initFlutter();
  runApp(const MediMindApp());
}
