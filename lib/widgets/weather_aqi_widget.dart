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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.secondaryNeon.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. DÒNG TIÊU ĐỀ: "THỜI TIẾT BUỔI CHẠY" & BADGE AQI
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
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
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

          const SizedBox(height: 10),

          // 2. KHỐI THÔNG SỐ: NHIỆT ĐỘ, TÌNH TRẠNG, ĐỘ ẨM, TỐC ĐỘ GIÓ (ĐẦY ĐỦ KHÔNG BỊ CẮT CHỮ)
          Row(
            children: [
              // Cột 1: Nhiệt độ lớn + Cảm giác thực
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${w.temperature.round()}°C',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                      height: 1.0,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Cảm giác ${w.apparentTemperature.round()}°C',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 14),

              // Cột 2: Tình trạng thời tiết (VD: Nhiều mây / Trời quang)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      w.weatherDescription,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Điều kiện thực tế',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

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
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
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

          const SizedBox(height: 9),

          // 3. LỜI KHUYÊN CHẠY BỘ THỂ THAO
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.divider.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tips_and_updates_outlined,
                  size: 13,
                  color: AppTheme.accentOrange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    w.sportAdvice,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
