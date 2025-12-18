class Config {
  static const String baseUrl = "https://jw.sdpei.edu.cn";
  static const String loginUrl = "$baseUrl/LoginHandler.ashx";
  static const String mainUrl = "$baseUrl/Navigation/main.aspx";
  static const String gradesUrl = "$baseUrl/Student/MyMark.aspx";
  static const String timetableAPI = "$baseUrl/Teacher/TimeTableHandler.ashx";
  static const String progressUrl = "$baseUrl/Student/MyProgramProgress.aspx";
  
  static const String userAgent = 
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/91.0.4472.124 Safari/537.36";
}
