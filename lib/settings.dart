import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  final String? apiEndpoint;
  final String? apiKey;
  final String? model;

  Settings({this.apiEndpoint, this.apiKey, this.model});

  static const _kEndpoint = 'ai_endpoint';
  static const _kApiKey = 'ai_api_key';
  static const _kModel = 'ai_model';

  static Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Settings(
      apiEndpoint: prefs.getString(_kEndpoint),
      apiKey: prefs.getString(_kApiKey),
      model: prefs.getString(_kModel),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (apiEndpoint != null) {
      await prefs.setString(_kEndpoint, apiEndpoint!);
    } else {
      await prefs.remove(_kEndpoint);
    }
    if (apiKey != null) {
      await prefs.setString(_kApiKey, apiKey!);
    } else {
      await prefs.remove(_kApiKey);
    }
    if (model != null) {
      await prefs.setString(_kModel, model!);
    } else {
      await prefs.remove(_kModel);
    }
  }
}

