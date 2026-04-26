import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/contact_provider.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final AppUpdateService _updateService = AppUpdateService();
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Check for updates FIRST before anything else (CRITICAL requirement)
    await _checkForUpdate();
    
    // Wait for splash animation minimum time
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Skip auth check if forced update is required
    if (_updateChecked) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.init();

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        final chatProvider = context.read<ChatProvider>();
        final contactProvider = context.read<ContactProvider>();
        await chatProvider.init(authProvider);
        
        // 设置好友请求回调：收到好友请求或接受好友时刷新联系人
        chatProvider.onFriendRequestReceived = () {
          contactProvider.loadFriendRequests();
          contactProvider.loadFriends();
        };
        
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  bool _updateDialogShown = false;

  Future<void> _checkForUpdate() async {
    // 防重复：确保只弹出一次更新对话框
    if (_updateDialogShown) {
      _updateChecked = true;
      return;
    }
    _updateDialogShown = true;

    try {
      final updateInfo = await _updateService.checkForUpdate();
      
      if (updateInfo != null && updateInfo.hasUpdate && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: !updateInfo.forceUpdate,
          builder: (context) => UpdateDialog(
            updateInfo: updateInfo,
            onDismiss: () {
              Navigator.of(context).pop();
            },
          ),
        );
      }
    } catch (e) {
      // 网络错误或检查更新失败时忽略，不阻塞应用启动
      print('Update check failed: $e');
    } finally {
      // 无论成功失败都要标记为检查完成，否则 app 永远卡在启动页
      _updateChecked = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF5B8DB8), Color(0xFF8FB8D8)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5B8DB8).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '言',
                          style: TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '序言',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '初见书序言，相伴为续言',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Color(0xFF5B8DB8)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
