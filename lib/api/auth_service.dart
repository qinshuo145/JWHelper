import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../config.dart';
import 'client.dart';
import 'package:flutter/rendering.dart';


class AuthService {
  final ApiClient _client = ApiClient();

  Future<Uint8List?> getCaptchaImage() async {
    try {
      String url = "${Config.BASE_URL}/LoginHandler.ashx?createvc=true&random=${DateTime.now().millisecondsSinceEpoch}";
      Response response = await _client.dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data);
    } catch (e) {
      debugPrint("Get captcha failed: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> login(String username, String password, {String verifyCode = ""}) async {
    String userIdEncoded = base64.encode(utf8.encode(username));
    String userPwdEncoded = base64.encode(utf8.encode(password));

    FormData formData = FormData.fromMap({
      "method": "DoLogin",
      "userId": userIdEncoded,
      "userPwd": userPwdEncoded,
      "verifyCode": verifyCode,
    });

    try {
      Response response = await _client.dio.post(Config.LOGIN_URL, data: formData);
      String result = response.data.toString();

      if (result.contains("true")) {
        return {"success": true, "message": "登录成功"};
      } else if (result.contains("verifyCodeTimeOut") || result.contains("wrongVerifyCode") || result.contains("showVC")) {
        return {"success": false, "needCaptcha": true, "message": "需要验证码"};
      } else {
        return {"success": false, "message": "登录失败: $result"};
      }
    } catch (e) {
      return {"success": false, "message": "网络错误: $e"};
    }
  }
}
