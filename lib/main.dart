import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open-Meteo Weather',
      debugShowCheckedModeBanner: false,
      home: const WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final TextEditingController _controller = TextEditingController();
  String city = "Da Nang";
  String country = "Vietnam";
  double? currentTemp;
  double? windSpeed;
  List<double> hourlyTemps = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    fetchWeather("Da Nang");
  }

  Future<void> fetchWeather(String cityName) async {
    try {
      setState(() => loading = true);

      // 1️⃣ Lấy tọa độ thành phố từ Open-Meteo Geocoding API
      final geoUrl =
          "https://geocoding-api.open-meteo.com/v1/search?name=$cityName&count=1";
      final geoRes = await http.get(Uri.parse(geoUrl));

      if (geoRes.statusCode != 200) {
        throw Exception("Không lấy được tọa độ");
      }

      final geoData = jsonDecode(geoRes.body);
      if (geoData["results"] == null || geoData["results"].isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Không tìm thấy thành phố"),
              duration: Duration(seconds: 2),
            ),
          );
        }
        _controller.clear();
        setState(() => loading = false);
        return;
      }

      final location = geoData["results"][0];
      double lat = location["latitude"];
      double lon = location["longitude"];
      String countryName = location["country"] ?? "";

      // 2️⃣ Gọi API thời tiết
      final weatherUrl =
          "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&hourly=temperature_2m&forecast_days=1";
      final weatherRes = await http.get(Uri.parse(weatherUrl));

      if (weatherRes.statusCode != 200) {
        throw Exception("Không lấy được dữ liệu thời tiết");
      }

      final weatherData = jsonDecode(weatherRes.body);
      double temp = weatherData["current_weather"]["temperature"];
      double wind = weatherData["current_weather"]["windspeed"];

      // Defensive read: hourly temperatures can contain ints, doubles, strings or nulls.
      // Make sure we get a List (or empty list) and convert values to finite doubles.
      List temps = weatherData["hourly"]?["temperature_2m"] ?? [];

      List<double> next12h = temps
          .where((e) => e != null)
          .map<double>(
            (e) => e is num
                ? e.toDouble()
                : (double.tryParse(e.toString()) ?? double.nan),
          )
          // drop NaN/Infinity values
          .where((d) => d.isFinite)
          .take(12)
          .toList();

      setState(() {
        city = cityName;
        country = countryName;
        currentTemp = temp;
        windSpeed = wind;
        hourlyTemps = next12h;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi: ${e.toString()}")));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Open-Meteo Weather",
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.cloud_outlined, color: Colors.grey),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Ô nhập thành phố
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: "Nhập tên thành phố...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) fetchWeather(value);
                },
              ),
              const SizedBox(height: 20),

              // Nếu đang tải
              if (loading)
                const CircularProgressIndicator()
              else if (currentTemp != null)
                Column(
                  children: [
                    // Thẻ thời tiết
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6DD5FA), Color(0xFF2980B9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "$city, $country",
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${currentTemp!.toStringAsFixed(1)}°C",
                            style: GoogleFonts.poppins(
                              fontSize: 48,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.air,
                                color: Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Gió: ${windSpeed!.toStringAsFixed(1)} km/h",
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tiêu đề Nhiệt độ 12 giờ tới
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.thermostat, color: Colors.redAccent),
                        const SizedBox(width: 6),
                        Text(
                          "Nhiệt độ 12 giờ tới:",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Danh sách nhiệt độ
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: hourlyTemps
                          .map(
                            (temp) => Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${temp.toStringAsFixed(1)}°C",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
