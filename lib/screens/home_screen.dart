import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../api/update_service.dart';
import 'grades_screen.dart';
import 'schedule_screen.dart';
import 'progress_screen.dart';
import 'exam_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const ScheduleScreen(),
    const ExamScreen(),
    const GradesScreen(),
    const ProgressScreen(),
  ];

  final UpdateService _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    _updateService.init();
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  Widget _buildAboutIcon() {
    return _updateService.buildAboutIcon();
  }

  Widget _buildUpdateSection() {
    return _updateService.buildUpdateSection(context);
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("关于我们", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF409EFF),
                    child: const Icon(Icons.school, size: 50, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "教务小助手",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (_updateService.currentVersion.isNotEmpty)
              Text("v${_updateService.currentVersion}", style: const TextStyle(color: Colors.grey))
            else
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text("v${snapshot.data!.version}", style: const TextStyle(color: Colors.grey));
                  }
                  return const Text("v...", style: TextStyle(color: Colors.grey));
                },
              ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () => launchUrl(Uri.parse("https://github.com/Sdpei-CTCA/JWHelper")),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link, size: 16, color: Colors.blue),
                  SizedBox(width: 4),
                  Text(
                    "GitHub 仓库",
                    style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildUpdateSection(),
            const SizedBox(height: 12),
            const Text(
              "GPL3.0 License",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              "Original Author:Chendayday-2025\nRemake by: Sdpei-CTCA",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("关闭"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "教务小助手",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            if (dataProvider.currentWeek > 0)
              Text(
                "第${dataProvider.currentWeek}周",
                style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _buildAboutIcon(),
            tooltip: "关于我们",
            onPressed: _showAboutDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF409EFF)),
            tooltip: "退出登录",
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final data = Provider.of<DataProvider>(context, listen: false);
              
              await auth.logout();
              data.clearAll();
              
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 2,
        destinations: const [ 
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: '课表',
          ),          
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: '考试',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '成绩',
          ),

          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: '进度',
          ),
        ],
      ),
    );
  }
}