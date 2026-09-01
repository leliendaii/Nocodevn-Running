import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Dữ liệu thời tiết và chất lượng không khí chuẩn thể thao
class WeatherData {
  final double temperature;        // °C
  final double apparentTemperature;// °C cảm nhận
  final int humidity;              // %
  final double windSpeed;          // km/h
  final int weatherCode;           // WMO code
  final String weatherDescription; // Mô tả tiếng Việt
  final IconData weatherIcon;      // Icon thời tiết
  final int aqi;                   // US AQI (0 - 500)
  final double pm25;               // Bụi mịn PM2.5 (ug/m3)
  final String aqiLabel;           // Trong lành, Trung bình, Ô nhiễm...
  final Color aqiColor;            // Màu sắc tương ứng
  final String sportAdvice;        // Lời khuyên chạy bộ

  const WeatherData({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.weatherDescription,
    required this.weatherIcon,
    required this.aqi,
    required this.pm25,
    required this.aqiLabel,
    required this.aqiColor,
    required this.sportAdvice,
  });
}

/// Dịch vụ lấy Thời tiết & Chất lượng không khí (AQI) từ Open-Meteo
class WeatherService {
  static WeatherData? _cachedData;
  static DateTime? _lastFetchTime;
  static double? _lastLat;
  static double? _lastLng;

  // Thời gian cache 30 phút để không spam mạng và không tốn pin
  static const Duration _cacheDuration = Duration(minutes: 30);

  /// Lấy thông tin thời tiết & AQI theo tọa độ GPS hiện tại
  static Future<WeatherData?> fetchWeatherAndAqi({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();

    // Kiểm tra cache hợp lệ
    if (!forceRefresh &&
        _cachedData != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < _cacheDuration &&
        _lastLat != null &&
        _lastLng != null &&
        (latitude - _lastLat!).abs() < 0.05 &&
        (longitude - _lastLng!).abs() < 0.05) {
      return _cachedData;
    }

    try {
      // 1. Gọi API Dự báo thời tiết Open-Meteo
      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m'
        '&timezone=auto',
      );

      // 2. Gọi API Chất lượng không khí Open-Meteo
      final aqiUrl = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality?'
        'latitude=$latitude&longitude=$longitude'
        '&current=us_aqi,pm2_5'
        '&timezone=auto',
      );

      final responses = await Future.wait([
        http.get(weatherUrl).timeout(const Duration(seconds: 6)),
        http.get(aqiUrl).timeout(const Duration(seconds: 6)),
      ]);

      final weatherRes = responses[0];
      final aqiRes = responses[1];

      if (weatherRes.statusCode != 200) return _cachedData;

      final weatherJson = jsonDecode(weatherRes.body) as Map<String, dynamic>;
      final current = weatherJson['current'] as Map<String, dynamic>? ?? {};

      final double temp = (current['temperature_2m'] as num?)?.toDouble() ?? 26.0;
      final double apparentTemp = (current['apparent_temperature'] as num?)?.toDouble() ?? temp;
      final int humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 65;
      final double wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 6.0;
      final int code = (current['weather_code'] as num?)?.toInt() ?? 0;

      // Xử lý AQI
      int aqiVal = 35;
      double pm25Val = 10.0;
      if (aqiRes.statusCode == 200) {
        try {
          final aqiJson = jsonDecode(aqiRes.body) as Map<String, dynamic>;
          final aqiCurrent = aqiJson['current'] as Map<String, dynamic>? ?? {};
          aqiVal = (aqiCurrent['us_aqi'] as num?)?.toInt() ?? 35;
          pm25Val = (aqiCurrent['pm2_5'] as num?)?.toDouble() ?? 10.0;
        } catch (_) {}
      }

      final weatherInfo = _parseWeatherCode(code);
      final aqiInfo = _parseAqi(aqiVal);
      final advice = _generateSportAdvice(temp, code, aqiVal);

      final result = WeatherData(
        temperature: temp,
        apparentTemperature: apparentTemp,
        humidity: humidity,
        windSpeed: wind,
        weatherCode: code,
        weatherDescription: weatherInfo.$1,
        weatherIcon: weatherInfo.$2,
        aqi: aqiVal,
        pm25: pm25Val,
        aqiLabel: aqiInfo.$1,
        aqiColor: aqiInfo.$2,
        sportAdvice: advice,
      );

      _cachedData = result;
      _lastFetchTime = now;
      _lastLat = latitude;
      _lastLng = longitude;

      return result;
    } catch (e) {
      debugPrint('Lỗi tải thời tiết Open-Meteo: $e');
      return _cachedData;
    }
  }

  /// Phân giải WMO Weather Code
  static (String, IconData) _parseWeatherCode(int code) {
    switch (code) {
      case 0:
        return ('Trời trong xanh', Icons.wb_sunny_rounded);
      case 1:
        return ('Trời quang mát', Icons.wb_sunny_outlined);
      case 2:
        return ('Mây rải rác', Icons.cloud_queue_rounded);
      case 3:
        return ('Nhiều mây', Icons.cloud_rounded);
      case 45:
      case 48:
        return ('Có sương mù', Icons.foggy);
      case 51:
      case 53:
      case 55:
        return ('Mưa phùn nhẹ', Icons.grain_rounded);
      case 61:
      case 63:
      case 65:
        return ('Mưa rào', Icons.umbrella_rounded);
      case 80:
      case 81:
      case 82:
        return ('Mưa rải rác', Icons.water_drop_rounded);
      case 95:
      case 96:
      case 99:
        return ('Có dông bão', Icons.flash_on_rounded);
      default:
        return ('Thời tiết dịu', Icons.wb_sunny_outlined);
    }
  }

  /// Phân giải US AQI (Air Quality Index)
  static (String, Color) _parseAqi(int aqi) {
    if (aqi <= 50) {
      return ('Trong lành', const Color(0xFF10B981)); // Xanh lá
    } else if (aqi <= 100) {
      return ('Trung bình', const Color(0xFFF59E0B)); // Vàng
    } else if (aqi <= 150) {
      return ('Kém nhẹ', const Color(0xFFFF9800));   // Cam
    } else {
      return ('Ô nhiễm', const Color(0xFFEF4444));   // Đỏ
    }
  }

  /// Tạo lời khuyên chạy bộ thông minh
  static String _generateSportAdvice(double temp, int code, int aqi) {
    if (code >= 61 && code <= 99) {
      return 'Đang có mưa, chú ý đường trơn trượt nhé!';
    }
    if (aqi > 150) {
      return 'Không khí ô nhiễm, nên chạy nhẹ nhàng hoặc đeo khẩu trang.';
    }
    if (temp >= 33.0) {
      return 'Trời nắng nóng, nhớ bù đủ nước điện giải khi chạy!';
    }
    if (temp <= 25.0 && aqi <= 50) {
      return 'Thời tiết mát mẻ lý tưởng, rất thích hợp để bứt phá hôm nay!';
    }
    return 'Thời tiết tốt, sẵn sàng cho một buổi chạy tuyệt vời!';
  }
}
