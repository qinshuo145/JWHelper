import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
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

  final Dio _dio = Dio(
    BaseOptions(
      headers: const {
        'User-Agent': 'JWHelper-App',
        'Accept': 'application/vnd.github+json',
      },
    ),
  );
  bool _checkingUpdate = false;
  bool _hasUpdate = false;
  double? _downloadProgress;
  String _currentVersion = '';
  String? _latestVersion;
  String? _releaseNotes;
  String? _downloadUrl;
  String? _updateError;

  static const String _githubLatestApi =
      'https://api.github.com/repos/Sdpei-CTCA/JWHelper/releases/latest';

  @override
  void initState() {
    super.initState();
    _initUpdateFlow();
  }

  Future<void> _initUpdateFlow() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _currentVersion = info.version);
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates(silent: true);
    });
  }

  String? _extractVersionFromText(String? text) {
    if (text == null) return null;
    final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(text);
    if (match == null) return null;
    return '${match.group(1)}.${match.group(2)}.${match.group(3)}';
  }

  bool _isNewerVersion(String latest, String current) {
    if (latest.isEmpty) return false;
    if (current.isEmpty) return true;
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  Future<String?> _pickAssetUrl(List<dynamic> assets) async {
    if (assets.isEmpty) return null;

    String? findForPattern(String pattern) {
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = asset['name'] as String? ?? '';
          if (name.toLowerCase().contains(pattern.toLowerCase())) {
            return asset['browser_download_url'] as String?;
          }
        }
      }
      return null;
    }

    List<String> supportedAbis = [];
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        supportedAbis = androidInfo.supportedAbis;
      } catch (_) {}
    }

    for (final abi in supportedAbis) {
      final url = findForPattern(abi);
      if (url != null) return url;
    }

    const fallbackOrder = ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];
    for (final pattern in fallbackOrder) {
      final url = findForPattern(pattern);
      if (url != null) return url;
    }

    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final url = asset['browser_download_url'] as String?;
        if (url != null) return url;
      }
    }
    return null;
  }

  Future<void> _checkForUpdates({bool silent = false}) async {
    if (_checkingUpdate) return;

    setState(() {
      _checkingUpdate = true;
      if (!silent) _updateError = null;
    });

    try {
      final response = await _dio.get(_githubLatestApi);
      final data = response.data as Map<String, dynamic>;

      final tag = data['tag_name'] as String?;
      final name = data['name'] as String?;
      final latest = _extractVersionFromText(tag) ?? _extractVersionFromText(name);
      if (latest == null) {
        throw Exception('未在发布信息中找到版本号');
      }

      final hasNew = _isNewerVersion(latest, _currentVersion);
      final assets = (data['assets'] as List<dynamic>?) ?? [];
      final assetUrl = await _pickAssetUrl(assets);
      final releaseNotes = data['body'] as String? ?? '';

      if (!hasNew) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前已是最新版本')),
          );
        }

        setState(() {
          _hasUpdate = false;
          _latestVersion = latest;
          _releaseNotes = releaseNotes;
          _downloadUrl = null;
        });
        return;
      }

      setState(() {
        _hasUpdate = true;
        _latestVersion = latest;
        _releaseNotes = releaseNotes;
        _downloadUrl = assetUrl;
        _updateError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _updateError = e.toString());
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('检查更新失败：$e')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  Future<void> _downloadLatestApk() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('仅支持在 Android 设备上下载 APK')),
        );
      }
      return;
    }

    if (_downloadUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到可用的下载链接')),
        );
      }
      return;
    }

    setState(() => _downloadProgress = 0);
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'JWHelper-${_latestVersion ?? 'latest'}.apk';
      final savePath = '${dir.path}/$fileName';
      final proxiedUrl = 'https://hk.gh-proxy.org/$_downloadUrl';

      await _dio.download(
        proxiedUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          if (total <= 0) return;
          setState(() => _downloadProgress = received / total);
        },
      );

      if (!mounted) return;
      setState(() => _downloadProgress = null);

      final opened = await launchUrl(
        Uri.file(savePath),
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已下载到: $savePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadProgress = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$e')),
        );
      }
    }
  }

  Widget _buildAboutIcon() {
    final icon = const Icon(Icons.info_outline, color: Color(0xFF409EFF));
    if (!_hasUpdate) return icon;
    return Badge(
      backgroundColor: Colors.amber,
      smallSize: 10,
      offset: const Offset(8, -8),
      child: icon,
    );
  }

  Widget _buildUpdateSection() {
    if (_checkingUpdate) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          SizedBox(width: 8),
          Text('正在检查更新...'),
        ],
      );
    }

    if (_hasUpdate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.new_releases, color: Colors.orange),
              const SizedBox(width: 6),
              Text('发现新版本 v${_latestVersion ?? ''}'),
            ],
          ),
          const SizedBox(height: 6),
          if ((_releaseNotes ?? '').isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _releaseNotes!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _downloadProgress != null ? null : _downloadLatestApk,
            icon: _downloadProgress != null
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: _downloadProgress,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(
              _downloadProgress != null
                  ? '下载中 ${(_downloadProgress! * 100).toStringAsFixed(0)}%'
                  : '立即下载',
            ),
          ),
          TextButton.icon(
            onPressed: () => _checkForUpdates(silent: false),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重新检查'),
          ),
        ],
      );
    }

    return Column(
      children: [
        FilledButton.icon(
          onPressed: () => _checkForUpdates(silent: false),
          icon: const Icon(Icons.system_update_alt),
          label: const Text('检查更新'),
        ),
        if (_updateError != null) ...[
          const SizedBox(height: 6),
          Text(
            _updateError!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
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
            if (_currentVersion.isNotEmpty)
              Text("v$_currentVersion", style: const TextStyle(color: Colors.grey))
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("教务小助手", style: TextStyle(color: Colors.black)),
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
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Provider.of<DataProvider>(context, listen: false).clearAll();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
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
