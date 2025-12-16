import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/grades_service.dart';
import '../api/schedule_service.dart';
import '../api/progress_service.dart';
import '../models/grade.dart';
import '../models/schedule_item.dart';
import '../models/progress_item.dart';

class DataProvider with ChangeNotifier {
  final GradesService _gradesService = GradesService();
  final ScheduleService _scheduleService = ScheduleService();
  final ProgressService _progressService = ProgressService();

  // Grades
  List<Grade> _grades = [];
  bool _gradesLoading = false;
  bool _gradesLoaded = false;
  List<Grade> get grades => _grades;
  bool get gradesLoading => _gradesLoading;
  bool get gradesLoaded => _gradesLoaded;

  // Schedule
  List<ScheduleItem> _schedule = [];
  bool _scheduleLoading = false;
  bool _scheduleLoaded = false;
  List<ScheduleItem> get schedule => _schedule;
  bool get scheduleLoading => _scheduleLoading;
  bool get scheduleLoaded => _scheduleLoaded;

  // Progress
  List<ProgressGroup> _progressGroups = [];
  List<ProgressInfo> _progressInfo = [];
  bool _progressLoading = false;
  bool _progressLoaded = false;
  List<ProgressGroup> get progressGroups => _progressGroups;
  List<ProgressInfo> get progressInfo => _progressInfo;
  bool get progressLoading => _progressLoading;
  bool get progressLoaded => _progressLoaded;

  String _username = '';

  void updateUsername(String username) {
    if (_username != username) {
      _username = username;
      // Clear memory data when switching users
      clearAll();
    }
  }

  // --- Grades Methods ---
  String get _gradesCacheKey => 'grades_cache_$_username';
  String get _gradesCacheTimeKey => 'grades_cache_time_$_username';

  Future<void> loadGrades({bool forceRefresh = false}) async {
    if (_gradesLoaded && !forceRefresh) return;
    if (_gradesLoading) return;
    if (_username.isEmpty) return; // Don't load if no user

    _gradesLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Try to load from cache if not forcing refresh
      if (!forceRefresh) {
        final int? lastTime = prefs.getInt(_gradesCacheTimeKey);
        final String? cachedData = prefs.getString(_gradesCacheKey);

        if (lastTime != null && cachedData != null) {
          final DateTime lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
          final DateTime now = DateTime.now();

          // Cache is valid for 30 days
          if (now.difference(lastFetchTime).inDays < 30) {
            final List<dynamic> decoded = jsonDecode(cachedData);
            _grades = decoded.map((e) => Grade.fromJson(e)).toList();
            _gradesLoaded = true;
            _gradesLoading = false;
            notifyListeners();
            return;
          }
        }
      }

      _grades = await _gradesService.getAllGrades();
      _gradesLoaded = true;
      
      // Save to cache
      await _saveGradesToCache(_grades);
    } catch (e) {
      debugPrint("Error loading grades: $e");
      // Try to load stale cache on error
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? cachedData = prefs.getString(_gradesCacheKey);
        if (cachedData != null) {
           final List<dynamic> decoded = jsonDecode(cachedData);
           _grades = decoded.map((e) => Grade.fromJson(e)).toList();
           _gradesLoaded = true;
        }
      } catch (cacheError) {
        debugPrint("Error loading stale cache: $cacheError");
      }
    } finally {
      _gradesLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveGradesToCache(List<Grade> grades) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(grades.map((g) => g.toJson()).toList());
      await prefs.setString(_gradesCacheKey, encoded);
      await prefs.setInt(_gradesCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint("Error saving grades cache: $e");
    }
  }

  // --- Schedule Methods ---
  String get _scheduleCacheKey => 'schedule_cache_$_username';
  String get _scheduleCacheTimeKey => 'schedule_cache_time_$_username';

  Future<void> loadSchedule({bool forceRefresh = false}) async {
    if (_scheduleLoaded && !forceRefresh) return;
    if (_scheduleLoading) return;
    if (_username.isEmpty) return;

    _scheduleLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Try to load from cache if not forcing refresh
      if (!forceRefresh) {
        final int? lastTime = prefs.getInt(_scheduleCacheTimeKey);
        final String? cachedData = prefs.getString(_scheduleCacheKey);

        if (lastTime != null && cachedData != null) {
          final DateTime lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
          final DateTime now = DateTime.now();

          // Cache is valid for 30 days for schedule
          if (now.difference(lastFetchTime).inDays < 30) {
            final List<dynamic> decoded = jsonDecode(cachedData);
            _schedule = decoded.map((e) => ScheduleItem.fromJson(e)).toList();
            _scheduleLoaded = true;
            _scheduleLoading = false;
            notifyListeners();
            return;
          }
        }
      }

      _schedule = await _scheduleService.getSchedule();
      _scheduleLoaded = true;
      
      // Save to cache
      await _saveScheduleToCache(_schedule);
    } catch (e) {
      debugPrint("Error loading schedule: $e");
      // Try to load stale cache on error
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? cachedData = prefs.getString(_scheduleCacheKey);
        if (cachedData != null) {
           final List<dynamic> decoded = jsonDecode(cachedData);
           _schedule = decoded.map((e) => ScheduleItem.fromJson(e)).toList();
           _scheduleLoaded = true;
        }
      } catch (cacheError) {
        debugPrint("Error loading stale schedule cache: $cacheError");
      }
    } finally {
      _scheduleLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveScheduleToCache(List<ScheduleItem> schedule) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(schedule.map((s) => s.toJson()).toList());
      await prefs.setString(_scheduleCacheKey, encoded);
      await prefs.setInt(_scheduleCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint("Error saving schedule cache: $e");
    }
  }

  String get _progressCacheKey => 'progress_cache_$_username';
  String get _progressCacheTimeKey => 'progress_cache_time_$_username';

  Future<void> loadProgress({bool forceRefresh = false}) async {
    if (_progressLoaded && !forceRefresh) return;
    if (_progressLoading) return;
    if (_username.isEmpty) return;

    _progressLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Try to load from cache if not forcing refresh
      if (!forceRefresh) {
        final int? lastTime = prefs.getInt(_progressCacheTimeKey);
        final String? cachedData = prefs.getString(_progressCacheKey);

        if (lastTime != null && cachedData != null) {
          final DateTime lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
          final DateTime now = DateTime.now();

          // Cache is valid for 30 days
          if (now.difference(lastFetchTime).inDays < 30) {
            final Map<String, dynamic> decoded = jsonDecode(cachedData);
            _progressGroups = (decoded['groups'] as List).map((e) => ProgressGroup.fromJson(e)).toList();
            _progressInfo = (decoded['info'] as List).map((e) => ProgressInfo.fromJson(e)).toList();
            _progressLoaded = true;
            _progressLoading = false;
            notifyListeners();
            return;
          }
        }
      }

      var data = await _progressService.getProgressData();
      _progressGroups = data['groups'] ?? [];
      _progressInfo = data['info'] ?? [];
      _progressLoaded = true;

      // Start background loading of details without awaiting
      _loadDetailsInBackground();
    } catch (e) {
      debugPrint("Error loading progress: $e");
      // Try to load stale cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? cachedData = prefs.getString(_progressCacheKey);
        if (cachedData != null) {
            final Map<String, dynamic> decoded = jsonDecode(cachedData);
            _progressGroups = (decoded['groups'] as List).map((e) => ProgressGroup.fromJson(e)).toList();
            _progressInfo = (decoded['info'] as List).map((e) => ProgressInfo.fromJson(e)).toList();
            _progressLoaded = true;
        }
      } catch (cacheError) {
         debugPrint("Error loading stale progress cache: $cacheError");
      }
    } finally {
      _progressLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadDetailsInBackground() async {
    if (_progressGroups.isEmpty) return;

    // Load details for each group
    var futures = _progressGroups.map((group) async {
      try {
        // Only load if not already loaded (though usually it's null here)
        if (group.courses == null) {
          group.courses = await _progressService.getGroupCourses(group.id);
          notifyListeners(); // Update UI as data comes in
        }
      } catch (e) {
        debugPrint("Error loading courses for group ${group.id}: $e");
      }
    });

    await Future.wait(futures);

    // Save to cache after all details are loaded
    await _saveProgressToCache(_progressGroups, _progressInfo);
  }

  Future<void> _saveProgressToCache(List<ProgressGroup> groups, List<ProgressInfo> info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {
        'groups': groups.map((g) => g.toJson()).toList(),
        'info': info.map((i) => i.toJson()).toList(),
      };
      final String encoded = jsonEncode(data);
      await prefs.setString(_progressCacheKey, encoded);
      await prefs.setInt(_progressCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint("Error saving progress cache: $e");
    }
  }

  Future<void> loadGroupCourses(ProgressGroup group) async {
    if (group.courses != null) return; // Already loaded

    try {
      var courses = await _progressService.getGroupCourses(group.id);
      group.courses = courses;
      // Update cache with new details
      await _saveProgressToCache(_progressGroups, _progressInfo);
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading group courses: $e");
      group.courses = []; // Stop loading spinner even on error
      notifyListeners();
    }
  }
  
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_gradesCacheKey);
    await prefs.remove(_gradesCacheTimeKey);
    await prefs.remove(_scheduleCacheKey);
    await prefs.remove(_scheduleCacheTimeKey);
    await prefs.remove(_progressCacheKey);
    await prefs.remove(_progressCacheTimeKey);
  }
  
  void clearAll() {
    _grades = [];
    _gradesLoaded = false;
    _schedule = [];
    _scheduleLoaded = false;
    _progressGroups = [];
    _progressInfo = [];
    _progressLoaded = false;
    notifyListeners();
  }
}
