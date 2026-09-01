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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.secondaryNeon.withValues(alpha: 0.35),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Dòng tiêu đề: Tên widget & Badge AQI kèm nhãn chất lượng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(w.weatherIcon, color: AppTheme.secondaryNeon, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'THỜI TIẾT BUỔI CHẠY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.secondaryNeon,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              // Badge AQI đầy đủ: ● AQI 76 • Trung bình
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: w.aqiColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: w.aqiColor.withValues(alpha: 0.6), width: 0.8),
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

          const SizedBox(height: 9),

          // 2. Lưới thông số đầy đủ: Nhiệt độ, Cảm giác, Tình trạng, Lời khuyên, Độ ẩm, Gió
          Row(
            children: [
              // Cột 1: Nhiệt độ thực tế & Cảm giác
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${w.temperature.round()}°C',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Cảm giác ${w.apparentTemperature.round()}°C',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // Cột 2: Tình trạng bầu trời & Lời khuyên chạy bộ ngắn
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      w.weatherDescription,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      w.sportAdvice,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Cột 3: Độ ẩm & Tốc độ gió
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '💧 Độ ẩm: ',
                        style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                      ),
                      Text(
                        '${w.humidity}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '💨 Gió: ',
                        style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                      ),
                      Text(
                        '${w.windSpeed.toStringAsFixed(1)} km/h',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
