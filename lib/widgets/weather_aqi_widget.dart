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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: AppTheme.secondaryNeon,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Đang cập nhật thời tiết...',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    if (_weather == null) return const SizedBox.shrink();

    final w = _weather!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.secondaryNeon.withValues(alpha: 0.3),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon thời tiết & Nhiệt độ
          Icon(
            w.weatherIcon,
            color: AppTheme.secondaryNeon,
            size: 18,
          ),
          const SizedBox(width: 7),
          Text(
            '${w.temperature.round()}°C',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '•',
            style: TextStyle(
              color: AppTheme.textMuted.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          // Tình trạng thời tiết ngắn gọn
          Expanded(
            child: Text(
              w.weatherDescription,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Độ ẩm
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💧', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 2),
              Text(
                '${w.humidity}%',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Badge AQI (Chất lượng không khí)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: w.aqiColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: w.aqiColor.withValues(alpha: 0.5), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: w.aqiColor,
                    boxShadow: [
                      BoxShadow(
                        color: w.aqiColor.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'AQI ${w.aqi}',
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
    );
  }
}
