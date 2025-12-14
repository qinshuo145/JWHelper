import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import '../config.dart';
import 'package:flutter/rendering.dart';


class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio dio;
  late CookieJar cookieJar;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: Config.BASE_URL,
      headers: {
        "User-Agent": Config.USER_AGENT,
        "Referer": "${Config.BASE_URL}/Login.aspx",
      },
      responseType: ResponseType.plain, // We handle HTML parsing manually
      validateStatus: (status) => status! < 500,
    ));
  }

  Future<void> init() async {
    // Default to in-memory cookies
    cookieJar = CookieJar();

    if (!kIsWeb) {
      try {
        // Try to use persistent cookies on mobile/desktop
        Directory appDocDir = await getApplicationDocumentsDirectory();
        String appDocPath = appDocDir.path;
        cookieJar = PersistCookieJar(storage: FileStorage("$appDocPath/.cookies/"));
      } catch (e) {
        // Ignore errors (like MissingPluginException) and keep using in-memory cookies
        debugPrint("Cookie persistence initialization failed: $e");
      }
    }
    
    dio.interceptors.add(CookieManager(cookieJar));
  }

  Future<void> clearCookies() async {
    await cookieJar.deleteAll();
  }
}
