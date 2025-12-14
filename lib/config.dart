class Config {
  static const String BASE_URL = "https://jw.sdpei.edu.cn";
  static const String LOGIN_URL = "$BASE_URL/LoginHandler.ashx";
  static const String MAIN_URL = "$BASE_URL/Navigation/main.aspx";
  static const String GRADES_URL = "$BASE_URL/Student/MyMark.aspx";
  static const String TIMETABLE_API = "$BASE_URL/Teacher/TimeTableHandler.ashx";
  static const String PROGRESS_URL = "$BASE_URL/Student/MyProgramProgress.aspx";
  
  static const String USER_AGENT = 
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/91.0.4472.124 Safari/537.36";
}
