import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/socket_service.dart';
import 'config/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize notification service
  await NotificationService().init();
  
  runApp(const XuYanApp());
}

class XuYanApp extends StatefulWidget {
  const XuYanApp({super.key});

  @override
  State<XuYanApp> createState() => _XuYanAppState();
}

class _XuYanAppState extends State<XuYanApp> {
  @override
  void initState() {
    super.initState();
    _initTheme();
    _listenToNotifications();
  }

  Future<void> _initTheme() async {
    // Theme is initialized in ThemeProvider
  }

  void _listenToNotifications() {
    NotificationService().onNotification.listen((data) {
      final type = data['type'];
      if (type == 'message') {
        // Handle message notification tap
        final conversationId = data['conversationId'] as String?;
        if (conversationId != null) {
          // Navigate to chat - this will be handled by the app
        }
      } else if (type == 'friend_request') {
        // Handle friend request notification tap
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final provider = ThemeProvider();
          provider.init();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
      ],
      child: const App(),
    );
  }
}
