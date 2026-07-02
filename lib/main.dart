import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pasar_malam/core/providers/theme_provider.dart';
import 'package:pasar_malam/core/routes/app_router.dart';
import 'package:pasar_malam/core/services/biometric_lock_provider.dart';
import 'package:pasar_malam/core/services/global_institute_pay_service.dart';
import 'package:pasar_malam/core/services/notification_service.dart';
import 'package:pasar_malam/core/theme/app_theme.dart';
import 'package:pasar_malam/core/widgets/biometric_lock_screen.dart';
import 'package:pasar_malam/features/auth/presentation/providers/auth_provider.dart';
import 'package:pasar_malam/features/cart/presentation/providers/cart_provider.dart';
import 'package:pasar_malam/features/dashboard/presentation/providers/product_provider.dart';
import 'package:pasar_malam/features/order/presentation/providers/order_provider.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  await GlobalInstitutePayService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(
          create: (_) => BiometricLockProvider()..initialize(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<PaymentCallbackData>? _callbackSub;
  bool _isHandlingCallback = false;

  @override
  void initState() {
    super.initState();
    _callbackSub =
        GlobalInstitutePayService().onCallback.listen(_handleCallback);
  }

  @override
  void dispose() {
    _callbackSub?.cancel();
    super.dispose();
  }

  Future<void> _handleCallback(PaymentCallbackData data) async {
    if (data.status != 'success') return;
    if (_isHandlingCallback) return;
    _isHandlingCallback = true;

    try {
      final ref = data.reference;
      if (ref != null && ref.startsWith('INV-')) {
        final orderId = int.tryParse(ref.replaceFirst('INV-', ''));
        if (orderId != null) {
          final navContext = AppRouter.navigatorKey.currentContext;
          if (navContext != null) {
            final orderProvider = navContext.read<OrderProvider>();
            final order = await orderProvider.getOrderDetail(orderId);
            if (order != null) {
              AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                AppRouter.orderSuccess,
                (route) => route.settings.name == AppRouter.dashboard,
                arguments: order,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PasarMalam/MyApp] Error handling global callback: $e');
    } finally {
      _isHandlingCallback = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      navigatorKey: AppRouter.navigatorKey,
      title: 'Home Living',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      initialRoute: AppRouter.splash,
      routes: AppRouter.routes,
      builder: (context, child) => BiometricLockScreen(child: child!),
    );
  }
}
