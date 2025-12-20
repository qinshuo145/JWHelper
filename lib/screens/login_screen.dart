import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      auth.init().then((error) {
        if (mounted) {
          if (auth.isLoggedIn) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          } else {
            if (error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("自动登录失败: $error"), backgroundColor: Colors.orange),
              );
            }
            if (auth.rememberPassword) {
              _usernameController.text = auth.savedUsername;
              _passwordController.text = auth.savedPassword;
            }
          }
        }
      });
    });
  }

  Future<void> _handleLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("请输入学号和密码"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final error = await auth.login(
        username,
        password,
        verifyCode: _captchaController.text,
      );

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
        // If captcha is needed, clear the captcha field
        if (auth.needCaptcha) {
          _captchaController.clear();
        }
      } else if (auth.isLoggedIn) {
        final dataProvider = Provider.of<DataProvider>(context, listen: false);

        if (!auth.isOfflineMode) {
          // Clear cache on manual login to force refresh
          await dataProvider.clearCache();

          if (!mounted) return;

          // Start loading all data in parallel
          dataProvider.loadGrades(forceRefresh: true);
          dataProvider.loadSchedule(forceRefresh: true);
          dataProvider.loadProgress(forceRefresh: true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("网络连接失败，已进入离线模式"),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          // Load from cache if available
          dataProvider.loadGrades();
          dataProvider.loadSchedule();
          dataProvider.loadProgress();
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      debugPrint("Login error: $e");
      if (mounted) {
        String errorMsg = "发生未知错误: $e";
        if (kIsWeb && e.toString().contains("XMLHttpRequest")) {
          errorMsg = "Web端存在跨域限制，无法直接访问教务系统。\n请使用 Windows 或 Android 客户端运行。";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              const Icon(Icons.school_rounded, size: 80, color: Color(0xFF409EFF))
                  .animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 16),
              const Text(
                "教务小助手",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF303133)),
              ).animate().fadeIn(delay: 200.ms).moveY(begin: 10, end: 0),
              const SizedBox(height: 8),
              const Text(
                "请使用学号和密码登录",
                style: TextStyle(fontSize: 14, color: Color(0xFF909399)),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 40),

              // Card
              Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: "学号",
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "密码",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                      ),
                    ),
                    
                    if (auth.needCaptcha) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _captchaController,
                              decoration: InputDecoration(
                                labelText: "验证码",
                                prefixIcon: const Icon(Icons.security),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: const Color(0xFFFAFAFA),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: auth.loadCaptcha,
                            child: auth.captchaImage != null
                                ? Image.memory(auth.captchaImage!, height: 50, fit: BoxFit.cover)
                                : Container(
                                    height: 50, width: 100,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.refresh),
                                  ),
                          ),
                        ],
                      ).animate().fadeIn(),
                    ],

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: auth.rememberPassword,
                            onChanged: (v) => auth.setRememberPassword(v ?? false),
                            activeColor: const Color(0xFF409EFF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text("记住密码", style: TextStyle(fontSize: 14, color: Color(0xFF606266))),
                        const Spacer(),
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: auth.autoLogin,
                            onChanged: (v) => auth.setAutoLogin(v ?? false),
                            activeColor: const Color(0xFF409EFF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text("自动登录", style: TextStyle(fontSize: 14, color: Color(0xFF606266))),
                      ],
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF409EFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: auth.isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("登 录", style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms).moveY(begin: 20, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}
