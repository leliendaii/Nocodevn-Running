import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';

/// Thẻ Thời tiết & Chất lượng không khí (AQI) thiết kế Kính mờ (Glassmorphism) Pro Sport
class WeatherAqiWidget extends StatefulWidget {
  const WeatherAqiWidget({super.key});

  @override
  State<WeatherAqiWidget> createState() => _WeatherAqiWidgetState();
}

class _WeatherAqiWidgetState extends State<WeatherAqiWidget> {
  WeatherData? _weather;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    try {
      double lat = 10.7769;
      double lng = 106.7009; // Mặc định TP.HCM

      try {
        final pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 3),
              ),
            );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      final data = await WeatherService.fetchWeatherAndAqi(
        latitude: lat,
        longitude: lng,
      );

      if (mounted) {
        setState(() {
          _weather = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.divider.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.secondaryNeon,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Đang cập nhật thời tiết buổi chạy...',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    if (_weather == null) return const SizedBox.shrink();

    final w = _weather!;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.secondaryNeon.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryNeon.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Icon thời tiết & Nhiệt độ
              Icon(
                w.weatherIcon,
                color: AppTheme.secondaryNeon,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                '${w.temperature.round()}°C',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              // Mô tả ngắn & độ ẩm
              Expanded(
                child: Text(
                  '${w.weatherDescription} • 💧 ${w.humidity}%',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // Badge AQI (Chất lượng không khí)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: w.aqiColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: w.aqiColor.withValues(alpha: 0.6), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: w.aqiColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'AQI ${w.aqi} • ${w.aqiLabel}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: w.aqiColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Lời khuyên chạy bộ ngắn gọn
          Row(
            children: [
              const Icon(
                Icons.tips_and_updates_outlined,
                size: 13,
                color: AppTheme.accentOrange,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  w.sportAdvice,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
