import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';

import 'src/auth/state/auth_view_model.dart';
import 'src/auth/data/auth_service.dart';
import 'src/core/services/connectivity_service.dart';
import 'src/core/services/analytics_service.dart';
import 'src/core/services/accessibility_service.dart';
import 'src/core/services/error_service.dart';
import 'src/core/services/loading_service.dart';
import 'src/core/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'src/core/services/storage_service.dart';
import 'src/home/view_models/search_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/home/home_screen.dart';
import 'src/core/theme/app_theme.dart';
import 'splash_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Görsel cache boyutlarını genişlet (kaydırma jank'ını azaltır)
  try {
    PaintingBinding.instance.imageCache.maximumSize = 300;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 256 << 20; // 256 MB
  } catch (_) {}
  // Register background handler before Firebase.initializeApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Firebase'i başlat
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue anyway - some services may still work
  }

  // AdMob'i başlat - Simulator'da test reklamları (ca-app-pub-3940256099942544/...) için gerekli
  try {
    await MobileAds.instance.initialize().timeout(const Duration(seconds: 8));
  } on TimeoutException {
    debugPrint('AdMob init timeout - reklamlar sonra yüklenecek');
  } catch (e) {
    debugPrint('AdMob init error: $e');
  }
  
  // Crashlytics'i yapılandır
  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  } catch (e) {
    debugPrint('Crashlytics initialization error: $e');
    // Continue anyway
  }
  
  // Kritik olmayan servisler arka planda (açılışı hızlandırır)
  final analyticsService = AnalyticsService();
  Future.microtask(() async {
    try {
      await ConnectivityService().initialize().timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      await analyticsService.setAnalyticsCollectionEnabled(true).timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await AccessibilityService().initialize().timeout(const Duration(seconds: 3));
    } catch (_) {}
  });
  NotificationService().initialize().timeout(const Duration(seconds: 5)).catchError((_) {});
  StorageService().cleanupTempFiles();
  
  // Global error handling - analytics hatası uygulamayı çökertmesin
  FlutterError.onError = (FlutterErrorDetails details) {
    try {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    } catch (_) {}
    try {
      analyticsService.logError(
        error: details.exception.toString(),
        screen: 'main',
      );
    } catch (_) {}
  };
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (context) => AuthViewModel(authService: context.read<AuthService>())),
        ChangeNotifierProvider.value(value: ConnectivityService()),
        Provider<AnalyticsService>(create: (_) => AnalyticsService()),
        ChangeNotifierProvider.value(value: AccessibilityService()),
        ChangeNotifierProvider.value(value: ErrorService()),
        ChangeNotifierProvider.value(value: LoadingService()),
        ChangeNotifierProvider.value(value: NotificationService()),
        Provider<StorageService>(create: (_) => StorageService()),
        ChangeNotifierProvider.value(value: SearchViewModel()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'GarageLoop',
        navigatorKey: rootNavigatorKey,
        
        // Localization support
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Force English UI only
        supportedLocales: const [Locale('en')],
        locale: const Locale('en'),
        localeResolutionCallback: (locale, supported) => const Locale('en'),
        
        theme: AppTheme.light,
        home: const _AuthGate(),
        // Analytics navigator observer
        navigatorObservers: [
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
        ],
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (snapshot.data != null) {
          // Kullanıcı giriş yaptığında analytics event'i gönder
          final analyticsService = context.read<AnalyticsService>();
          analyticsService.logUserLogin();
          analyticsService.setUserProperties(userId: snapshot.data!.uid);
          return const HomeScreen();
        }
        // Oturum yoksa varsayilan olarak ana sayfaya izin ver (misafir modu)
        // Gerekli aksiyonlarda (ilan olusturma, mesajlasma vb.) uygulama icinde
        // ayrica kimlik dogrulama kontrolu yapilir ve gerekirse AuthScreen'e yonlendirilir.
        return const HomeScreen();
      },
    );
  }
}

