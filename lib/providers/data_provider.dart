import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/grades_service.dart';
import '../api/schedule_service.dart';
import '../api/progress_service.dart';
import '../api/exam_service.dart';
import '../models/grade.dart';
import '../models/schedule_item.dart';
import '../models/progress_item.dart';
import '../models/exam.dart';

class DataProvider with ChangeNotifier {
  final GradesService _gradesService = GradesService();
  final ScheduleService _scheduleService = ScheduleService();
  final ProgressService _progressService = ProgressService();
  final ExamService _examService = ExamService();

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

  // Exams
  List<Semester> _examSemesters = [];
  List<ExamRound> _examRounds = [];
  List<Exam> _exams = [];
  bool _examsLoading = false;
  bool _examsLoaded = false;
  List<Semester> get examSemesters => _examSemesters;
  List<ExamRound> get examRounds => _examRounds;
  List<Exam> get exams => _exams;
  bool get examsLoading => _examsLoading;
  bool get examsLoaded => _examsLoaded;

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

  // --- Exam Methods ---
  String get _examSemestersCacheKey => 'exam_semesters_$_username';
  String _examRoundsCacheKey(String semId) => 'exam_rounds_${semId}_$_username';
  String _examsCacheKey(String semId, String roundId) => 'exams_${semId}_${roundId}_$_username';

  Future<void> loadExamSemesters({bool forceRefresh = false}) async {
    if (_examSemesters.isNotEmpty && !forceRefresh) return;
    if (_username.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!forceRefresh) {
        final String? cachedData = prefs.getString(_examSemestersCacheKey);
        if (cachedData != null) {
          final List<dynamic> decoded = jsonDecode(cachedData);
          _examSemesters = decoded.map((e) => Semester.fromJson(e)).toList();
          notifyListeners();
          return;
        }
      }

      _examSemesters = await _examService.getSemesters();
      
      // Save to cache
      final String encoded = jsonEncode(_examSemesters.map((e) => e.toJson()).toList());
      await prefs.setString(_examSemestersCacheKey, encoded);
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading exam semesters: $e");
      // Try stale cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? cachedData = prefs.getString(_examSemestersCacheKey);
        if (cachedData != null) {
          final List<dynamic> decoded = jsonDecode(cachedData);
          _examSemesters = decoded.map((e) => Semester.fromJson(e)).toList();
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  Future<void> loadExamRounds(String semId, {bool forceRefresh = false}) async {
    if (_username.isEmpty) return;
    
    // We don't check if _examRounds is not empty because it depends on semId
    // But we could check if the current _examRounds matches the cache for this semId?
    // For simplicity, we just load.

    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = _examRoundsCacheKey(semId);

      if (!forceRefresh) {
        final String? cachedData = prefs.getString(key);
        if (cachedData != null) {
          final List<dynamic> decoded = jsonDecode(cachedData);
          _examRounds = decoded.map((e) => ExamRound.fromJson(e)).toList();
          notifyListeners();
          return;
        }
      }

      _examRounds = await _examService.getExamRounds(semId);
      
      // Save to cache
      final String encoded = jsonEncode(_examRounds.map((e) => e.toJson()).toList());
      await prefs.setString(key, encoded);
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading exam rounds: $e");
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? cachedData = prefs.getString(_examRoundsCacheKey(semId));
        if (cachedData != null) {
          final List<dynamic> decoded = jsonDecode(cachedData);
          _examRounds = decoded.map((e) => ExamRound.fromJson(e)).toList();
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  Future<void> loadExams(String semId, String roundId, {bool forceRefresh = false}) async {
    if (_username.isEmpty) return;
    
    _examsLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = _examsCacheKey(semId, roundId);

      if (!forceRefresh) {
        final String? cachedData = prefs.getString(key);
        if (cachedData != null) {
          final List<dynamic> decoded = jsonDecode(cachedData);
          _exams = decoded.map((e) => Exam.fromJson(e)).toList();
          _examsLoaded = true;
          _examsLoading = false;
          notifyListeners();
          return;
        }
      }

      _exams = await _examService.getExamList(semId, roundId);
      _examsLoaded = true;
      
      // Save to cache
      final String encoded = jsonEncode(_exams.map((e) => e.toJson()).toList());
      await prefs.setString(key, encoded);
    } catch (e) {
      debugPrint("Error loading exams: $e");
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? cachedData = prefs.getString(_examsCacheKey(semId, roundId));
        if (cachedData != null) {
          final List<dynamic> decoded = jsonDecode(cachedData);
          _exams = decoded.map((e) => Exam.fromJson(e)).toList();
          _examsLoaded = true;
        }
      } catch (_) {}
    } finally {
      _examsLoading = false;
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
    
    // Clear exam caches - this is harder because keys are dynamic
    // We can iterate all keys and remove those starting with exam_
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('exam_') || key.startsWith('exams_')) {
        if (key.contains(_username)) {
          await prefs.remove(key);
        }
      }
    }
  }
  
  void clearAll() {
    _grades = [];
    _gradesLoaded = false;
    _schedule = [];
    _scheduleLoaded = false;
    _progressGroups = [];
    _progressInfo = [];
    _progressLoaded = false;
    _examSemesters = [];
    _examRounds = [];
    _exams = [];
    _examsLoaded = false;
    notifyListeners();
  }
}
