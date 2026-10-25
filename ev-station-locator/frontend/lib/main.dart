// ignore_for_file: prefer_interpolation_to_compose_strings, unnecessary_underscores, use_build_context_synchronously, curly_braces_in_flow_control_structures
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/ranking.dart';
import 'services/firestore_repository.dart';

const Color kPrimaryGreen = Color(0xFF087F5B);
const Color kEmerald = Color(0xFF10B981);
const Color kDarkBackground = Color(0xFF0F172A);
const Color kSurfaceColor = Color(0xFFF8FAFC);
const Color kCardBg = Colors.white;

// Fallback seed stations matching the backend seed database for 100% offline reliability
const List<Map<String, dynamic>> kDefaultStations = [
  {
    'id': 1,
    'name': 'ChargeZone Gachibowli',
    'provider': 'ChargeZone',
    'latitude': 17.4401,
    'longitude': 78.3814,
    'address': 'Gachibowli Rd, Financial District',
    'city': 'Hyderabad',
    'charging_power_kw': 60.0,
    'price_per_kwh': 16.0,
    'status': 'AVAILABLE',
    'opening_hours': '24/7',
    'distance_km': 3.8,
    'total_connectors': 4,
    'available_connectors': 3,
    'rating': 4.8,
    'review_count': 42,
    'connectors': [
      {'id': 1, 'connector_type': 'CCS2', 'power_kw': 60.0, 'status': 'AVAILABLE'},
      {'id': 2, 'connector_type': 'Type 2', 'power_kw': 80.0, 'status': 'AVAILABLE'},
      {'id': 3, 'connector_type': 'CHAdeMO', 'power_kw': 100.0, 'status': 'AVAILABLE'},
      {'id': 4, 'connector_type': 'AC DC', 'power_kw': 120.0, 'status': 'OCCUPIED'},
    ],
  },
  {
    'id': 2,
    'name': 'Tata Power Kondapur',
    'provider': 'Tata Power',
    'latitude': 17.4540,
    'longitude': 78.3735,
    'address': 'Kondapur Main Road',
    'city': 'Hyderabad',
    'charging_power_kw': 50.0,
    'price_per_kwh': 17.0,
    'status': 'AVAILABLE',
    'opening_hours': '24/7',
    'distance_km': 4.6,
    'total_connectors': 4,
    'available_connectors': 2,
    'rating': 4.6,
    'review_count': 28,
    'connectors': [
      {'id': 5, 'connector_type': 'CCS2', 'power_kw': 50.0, 'status': 'AVAILABLE'},
      {'id': 6, 'connector_type': 'Type 2', 'power_kw': 60.0, 'status': 'AVAILABLE'},
      {'id': 7, 'connector_type': 'CHAdeMO', 'power_kw': 70.0, 'status': 'OCCUPIED'},
      {'id': 8, 'connector_type': 'AC DC', 'power_kw': 80.0, 'status': 'OCCUPIED'},
    ],
  },
  {
    'id': 3,
    'name': 'Zeon Banjara Hills',
    'provider': 'Zeon',
    'latitude': 17.4140,
    'longitude': 78.4260,
    'address': 'Road No. 12, Banjara Hills',
    'city': 'Hyderabad',
    'charging_power_kw': 80.0,
    'price_per_kwh': 18.5,
    'status': 'OCCUPIED',
    'opening_hours': '06:00-23:00',
    'distance_km': 6.1,
    'total_connectors': 4,
    'available_connectors': 1,
    'rating': 4.5,
    'review_count': 35,
    'connectors': [
      {'id': 9, 'connector_type': 'CCS2', 'power_kw': 80.0, 'status': 'OCCUPIED'},
      {'id': 10, 'connector_type': 'Type 2', 'power_kw': 100.0, 'status': 'AVAILABLE'},
      {'id': 11, 'connector_type': 'CHAdeMO', 'power_kw': 120.0, 'status': 'OCCUPIED'},
      {'id': 12, 'connector_type': 'AC DC', 'power_kw': 140.0, 'status': 'OCCUPIED'},
    ],
  },
  {
    'id': 4,
    'name': 'Statiq Madhapur',
    'provider': 'Statiq',
    'latitude': 17.4418,
    'longitude': 78.3904,
    'address': 'Madhapur Metro Station Exit B',
    'city': 'Hyderabad',
    'charging_power_kw': 120.0,
    'price_per_kwh': 19.0,
    'status': 'AVAILABLE',
    'opening_hours': '24/7',
    'distance_km': 5.2,
    'total_connectors': 4,
    'available_connectors': 3,
    'rating': 4.9,
    'review_count': 56,
    'connectors': [
      {'id': 13, 'connector_type': 'CCS2', 'power_kw': 120.0, 'status': 'AVAILABLE'},
      {'id': 14, 'connector_type': 'Type 2', 'power_kw': 120.0, 'status': 'AVAILABLE'},
      {'id': 15, 'connector_type': 'CHAdeMO', 'power_kw': 120.0, 'status': 'AVAILABLE'},
      {'id': 16, 'connector_type': 'AC DC', 'power_kw': 120.0, 'status': 'OCCUPIED'},
    ],
  },
  {
    'id': 5,
    'name': 'Jio-bp Hitech City',
    'provider': 'Jio-bp',
    'latitude': 17.4511,
    'longitude': 78.3856,
    'address': 'Hitech City Cyber Towers',
    'city': 'Hyderabad',
    'charging_power_kw': 90.0,
    'price_per_kwh': 15.5,
    'status': 'AVAILABLE',
    'opening_hours': '24/7',
    'distance_km': 4.9,
    'total_connectors': 4,
    'available_connectors': 4,
    'rating': 4.7,
    'review_count': 19,
    'connectors': [
      {'id': 17, 'connector_type': 'CCS2', 'power_kw': 90.0, 'status': 'AVAILABLE'},
      {'id': 18, 'connector_type': 'Type 2', 'power_kw': 90.0, 'status': 'AVAILABLE'},
      {'id': 19, 'connector_type': 'CHAdeMO', 'power_kw': 90.0, 'status': 'AVAILABLE'},
      {'id': 20, 'connector_type': 'AC DC', 'power_kw': 90.0, 'status': 'AVAILABLE'},
    ],
  },
  {
    'id': 6,
    'name': 'Tata Power Shamshabad',
    'provider': 'Tata Power',
    'latitude': 17.2383,
    'longitude': 78.4291,
    'address': 'Airport Road, RGIA Access',
    'city': 'Hyderabad',
    'charging_power_kw': 60.0,
    'price_per_kwh': 14.5,
    'status': 'AVAILABLE',
    'opening_hours': '24/7',
    'distance_km': 18.2,
    'total_connectors': 4,
    'available_connectors': 3,
    'rating': 4.7,
    'review_count': 64,
    'connectors': [
      {'id': 21, 'connector_type': 'CCS2', 'power_kw': 60.0, 'status': 'AVAILABLE'},
      {'id': 22, 'connector_type': 'Type 2', 'power_kw': 60.0, 'status': 'AVAILABLE'},
      {'id': 23, 'connector_type': 'CHAdeMO', 'power_kw': 60.0, 'status': 'AVAILABLE'},
      {'id': 24, 'connector_type': 'AC DC', 'power_kw': 60.0, 'status': 'OCCUPIED'},
    ],
  },
  {
    'id': 7,
    'name': 'ChargeZone Kukatpally',
    'provider': 'ChargeZone',
    'latitude': 17.4948,
    'longitude': 78.3983,
    'address': 'Kukatpally Housing Board',
    'city': 'Hyderabad',
    'charging_power_kw': 50.0,
    'price_per_kwh': 16.0,
    'status': 'MAINTENANCE',
    'opening_hours': '08:00-20:00',
    'distance_km': 8.7,
    'total_connectors': 4,
    'available_connectors': 0,
    'rating': 4.1,
    'review_count': 12,
    'connectors': [
      {'id': 25, 'connector_type': 'CCS2', 'power_kw': 50.0, 'status': 'MAINTENANCE'},
      {'id': 26, 'connector_type': 'Type 2', 'power_kw': 50.0, 'status': 'MAINTENANCE'},
      {'id': 27, 'connector_type': 'CHAdeMO', 'power_kw': 50.0, 'status': 'MAINTENANCE'},
      {'id': 28, 'connector_type': 'AC DC', 'power_kw': 50.0, 'status': 'MAINTENANCE'},
    ],
  },
  {
    'id': 8,
    'name': 'Zeon Ameerpet',
    'provider': 'Zeon',
    'latitude': 17.4351,
    'longitude': 78.4484,
    'address': 'Ameerpet Commercial Hub',
    'city': 'Hyderabad',
    'charging_power_kw': 50.0,
    'price_per_kwh': 17.5,
    'status': 'AVAILABLE',
    'opening_hours': '24/7',
    'distance_km': 7.4,
    'total_connectors': 4,
    'available_connectors': 2,
    'rating': 4.4,
    'review_count': 23,
    'connectors': [
      {'id': 29, 'connector_type': 'CCS2', 'power_kw': 50.0, 'status': 'AVAILABLE'},
      {'id': 30, 'connector_type': 'Type 2', 'power_kw': 50.0, 'status': 'AVAILABLE'},
      {'id': 31, 'connector_type': 'CHAdeMO', 'power_kw': 50.0, 'status': 'OCCUPIED'},
      {'id': 32, 'connector_type': 'AC DC', 'power_kw': 50.0, 'status': 'OCCUPIED'},
    ],
  },
  {
    'id': 9,
    'name': 'Statiq ORR',
    'provider': 'Statiq',
    'latitude': 17.3822,
    'longitude': 78.4738,
    'address': 'Outer Ring Rd Toll Plaza',
    'city': 'Hyderabad',
    'charging_power_kw': 150.0,
    'price_per_kwh': 20.0,
    'status': 'AVAILABLE',
    'opening_hours': '24/7',
    'distance_km': 11.0,
    'total_connectors': 4,
    'available_connectors': 4,
    'rating': 4.9,
    'review_count': 81,
    'connectors': [
      {'id': 33, 'connector_type': 'CCS2', 'power_kw': 150.0, 'status': 'AVAILABLE'},
      {'id': 34, 'connector_type': 'Type 2', 'power_kw': 150.0, 'status': 'AVAILABLE'},
      {'id': 35, 'connector_type': 'CHAdeMO', 'power_kw': 150.0, 'status': 'AVAILABLE'},
      {'id': 36, 'connector_type': 'AC DC', 'power_kw': 150.0, 'status': 'AVAILABLE'},
    ],
  },
  {
    'id': 10,
    'name': 'Jio-bp Secunderabad',
    'provider': 'Jio-bp',
    'latitude': 17.4399,
    'longitude': 78.4984,
    'address': 'Station Road, Secunderabad',
    'city': 'Hyderabad',
    'charging_power_kw': 60.0,
    'price_per_kwh': 15.0,
    'status': 'OCCUPIED',
    'opening_hours': '06:00-23:00',
    'distance_km': 12.5,
    'total_connectors': 4,
    'available_connectors': 1,
    'rating': 4.3,
    'review_count': 30,
    'connectors': [
      {'id': 37, 'connector_type': 'CCS2', 'power_kw': 60.0, 'status': 'OCCUPIED'},
      {'id': 38, 'connector_type': 'Type 2', 'power_kw': 60.0, 'status': 'OCCUPIED'},
      {'id': 39, 'connector_type': 'CHAdeMO', 'power_kw': 60.0, 'status': 'AVAILABLE'},
      {'id': 40, 'connector_type': 'AC DC', 'power_kw': 60.0, 'status': 'OCCUPIED'},
    ],
  },
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (!kIsWeb) {
      await Firebase.initializeApp().timeout(const Duration(seconds: 2));
    }
  } catch (_) {}
  runApp(const ChargewiseApp());
}

class ApiClient {
  final List<String> _candidateBases = [
    const String.fromEnvironment('API_BASE_URL', defaultValue: ''),
    'http://127.0.0.1:5001/api',
    'http://127.0.0.1:5000/api',
    'http://localhost:5001/api',
    'http://localhost:5000/api',
  ].where((s) => s.isNotEmpty).toList();

  String? _workingBaseUrl;
  String? token;
  Map<String, dynamic>? currentUser;

  Future<String> resolveBaseUrl() async {
    if (_workingBaseUrl != null) return _workingBaseUrl!;
    for (final base in _candidateBases) {
      final clean = base.replaceFirst(RegExp(r'/+$'), '');
      final url = clean.endsWith('/api') ? clean : '$clean/api';
      try {
        final res = await http.get(Uri.parse(url + '/stations/')).timeout(const Duration(milliseconds: 1200));
        if (res.statusCode < 500) {
          _workingBaseUrl = url;
          return url;
        }
      } catch (_) {}
    }
    _workingBaseUrl = 'http://127.0.0.1:5001/api';
    return _workingBaseUrl!;
  }

  Future<dynamic> call(String path, {Map<String, dynamic>? body, String method = 'GET'}) async {
    final base = await resolveBaseUrl();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse(base + path);
    http.Response response;
    try {
      if (body != null || method == 'POST') {
        response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 4));
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 4));
      } else {
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      throw Exception('Network connection failed ($e)');
    }

    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw Exception('Server returned invalid data format');
      }
    }
    if (response.statusCode >= 400) {
      throw Exception(data is Map ? (data['error'] ?? 'Request failed (${response.statusCode})') : 'Request failed (${response.statusCode})');
    }
    return data;
  }
}

class StationStore extends ChangeNotifier {
  StationStore(this.api);
  final ApiClient api;

  List<Map<String, dynamic>> stations = List.from(kDefaultStations);
  List<RankedStation> ranked = [];
  final Set<String> favourites = {'1', '4'};
  final Set<String> compareSelection = {};
  final FirestoreRepository firestore = FirestoreRepository();

  String connectorFilter = '';
  double? maxDistanceKm;
  double? minPowerKw;
  bool availableOnly = false;
  String sortCriterion = 'Recommended';

  String vehicleModel = 'MG ZS EV';
  String vehicleConnector = 'CCS2';
  double? batteryPercent = 75.0;
  double? batteryCapacityKwh = 50.0;
  double? efficiencyKmPerKwh = 6.0;
  double? vehicleMaxPowerKw = 60.0;

  RankingWeights rankingWeights = const RankingWeights();
  String personalizationNote = 'Smart multi-factor EV ranking';
  bool loading = false;
  String? error;
  Position? position;
  String activeLocationName = 'Hyderabad, Telangana';
  bool isLiveBackend = false;
  List<Map<String, dynamic>> userReservations = [];

  Future<void> load([String query = '']) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final raw = await api.call('/stations/?q=' + Uri.encodeQueryComponent(query));
      if (raw is List && raw.isNotEmpty) {
        stations = raw.map((x) => Map<String, dynamic>.from(x as Map)).toList();
        isLiveBackend = true;
      } else {
        stations = List.from(kDefaultStations);
        isLiveBackend = false;
      }
      await _loadPersonalization();
      _rank();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      // Keep rich default stations so the user always has a functional app
      if (stations.isEmpty) {
        stations = List.from(kDefaultStations);
      }
      isLiveBackend = false;
      _rank();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadPersistedProfile() async {
    final user = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        favourites.addAll(
          (await firestore.favourites(user.uid)).map((item) => (item['stationId'] ?? item['id']).toString()),
        );
        final vehicle = await firestore.primaryVehicle(user.uid);
        if (vehicle != null) {
          setVehicle(
            model: vehicle['model'] as String? ?? vehicleModel,
            connector: vehicle['connector'] as String? ?? '',
            battery: (vehicle['battery'] as num?)?.toDouble(),
            capacity: (vehicle['capacity'] as num?)?.toDouble(),
            efficiency: (vehicle['efficiency'] as num?)?.toDouble(),
            maxPower: (vehicle['maxPower'] as num?)?.toDouble(),
          );
        }
      } catch (_) {}
    }
  }

  List<Map<String, dynamic>> get filteredStations {
    final list = stations.where((s) {
      final distance = (s['distance_km'] as num?)?.toDouble();
      final power = (s['charging_power_kw'] as num?)?.toDouble();
      final connectors = ((s['connectors'] as List?) ?? []).map(
        (c) => c is Map ? c['connector_type'].toString().toLowerCase() : c.toString().toLowerCase(),
      );
      if (maxDistanceKm != null && (distance == null || distance > maxDistanceKm!)) {
        return false;
      }
      if (minPowerKw != null && (power == null || power < minPowerKw!)) {
        return false;
      }
      if (connectorFilter.isNotEmpty && !connectors.any((c) => c.contains(connectorFilter.toLowerCase()))) {
        return false;
      }
      if (availableOnly && s['status'] != 'AVAILABLE') {
        return false;
      }
      return true;
    }).toList();

    if (sortCriterion == 'Nearest') {
      list.sort((a, b) => ((a['distance_km'] as num?) ?? 999).compareTo((b['distance_km'] as num?) ?? 999));
    } else if (sortCriterion == 'Highest Power') {
      list.sort((a, b) => ((b['charging_power_kw'] as num?) ?? 0).compareTo((a['charging_power_kw'] as num?) ?? 0));
    } else if (sortCriterion == 'Lowest Price') {
      list.sort((a, b) => ((a['price_per_kwh'] as num?) ?? 999).compareTo((b['price_per_kwh'] as num?) ?? 999));
    }
    return list;
  }

  void _rank() {
    ranked = StationRanker.rank(
      stations.map(
        (s) => StationCandidate(
          id: s['id'].toString(),
          distanceKm: (s['distance_km'] as num?)?.toDouble() ?? 999,
          connectorTypes: ((s['connectors'] as List?) ?? []).map((c) => c is Map ? c['connector_type'].toString() : c.toString()).toList(),
          maxPowerKw: (s['charging_power_kw'] as num?)?.toDouble() ?? 0,
          availableConnectors: (s['available_connectors'] as num?)?.toInt(),
          totalConnectors: (s['total_connectors'] as num?)?.toInt(),
          pricePerKwh: (s['price_per_kwh'] as num?)?.toDouble(),
          rating: (s['rating'] as num?)?.toDouble(),
          reviewCount: (s['review_count'] as num?)?.toInt() ?? 0,
          availabilityUpdatedAt: DateTime.tryParse(s['availability_updated_at']?.toString() ?? ''),
        ),
      ),
      RankingContext(
        requiredConnectors: vehicleConnector.isEmpty ? const [] : [vehicleConnector],
        batteryPercent: batteryPercent,
        batteryCapacityKwh: batteryCapacityKwh,
        efficiencyKmPerKwh: efficiencyKmPerKwh,
        vehicleMaxPowerKw: vehicleMaxPowerKw,
        weights: rankingWeights,
      ),
    );
  }

  Future<void> _loadPersonalization() async {
    final user = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final choices = await firestore.recentChoices(user.uid);
      if (choices.length < 3) return;
      final distances = choices.map((c) => (c['distanceKm'] as num?)?.toDouble()).whereType<double>().toList();
      final powers = choices.map((c) => (c['powerKw'] as num?)?.toDouble()).whereType<double>().toList();
      final prices = choices.map((c) => (c['pricePerKwh'] as num?)?.toDouble()).whereType<double>().toList();
      var distanceWeight = .15, speedWeight = .15, priceWeight = .10;
      if (distances.isNotEmpty && distances.reduce((a, b) => a + b) / distances.length <= 10) {
        distanceWeight += .04;
      }
      if (powers.isNotEmpty && powers.reduce((a, b) => a + b) / powers.length >= 100) {
        speedWeight += .04;
      }
      if (prices.isNotEmpty && prices.reduce((a, b) => a + b) / prices.length <= 20) {
        priceWeight += .03;
      }
      rankingWeights = RankingWeights(
        distance: distanceWeight,
        speed: speedWeight,
        price: priceWeight,
      );
      personalizationNote = 'Adjusted within bounded limits from recent choices';
    } catch (_) {}
  }

  void updateFilters({
    String? connector,
    double? distance,
    double? power,
    bool? available,
    String? sort,
  }) {
    connectorFilter = connector ?? connectorFilter;
    maxDistanceKm = distance;
    minPowerKw = power;
    availableOnly = available ?? availableOnly;
    sortCriterion = sort ?? sortCriterion;
    notifyListeners();
  }

  void setVehicle({
    String? model,
    required String connector,
    double? battery,
    double? capacity,
    double? efficiency,
    double? maxPower,
  }) {
    if (model != null && model.isNotEmpty) vehicleModel = model;
    vehicleConnector = connector;
    batteryPercent = battery;
    batteryCapacityKwh = capacity;
    efficiencyKmPerKwh = efficiency;
    vehicleMaxPowerKw = maxPower;
    _rank();
    notifyListeners();
  }

  Future<void> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
      position = await Geolocator.getCurrentPosition();
      activeLocationName = 'Current Location (${position!.latitude.toStringAsFixed(3)}, ${position!.longitude.toStringAsFixed(3)})';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggle(String id, [Map<String, dynamic>? station]) async {
    final adding = !favourites.contains(id);
    adding ? favourites.add(id) : favourites.remove(id);
    notifyListeners();
    final user = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (adding) {
        await firestore.setFavourite(user.uid, id, station ?? {'stationId': id});
      } else {
        await firestore.removeFavourite(user.uid, id);
      }
    }
  }

  void toggleCompare(String id) {
    compareSelection.contains(id) ? compareSelection.remove(id) : compareSelection.add(id);
    notifyListeners();
  }

  Future<void> recordChoice(Map<String, dynamic> station, double score) async {
    final user = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
    if (user != null) {
      await firestore.addChoice(user.uid, {
        'stationId': station['id'],
        'score': score,
        'distanceKm': station['distance_km'],
        'powerKw': station['charging_power_kw'],
        'pricePerKwh': station['price_per_kwh'],
        'connector': vehicleConnector,
        'batteryPercent': batteryPercent,
      });
    }
  }

  Future<void> saveVehicle(Map<String, dynamic> vehicle) async {
    setVehicle(
      model: vehicle['model'] as String? ?? vehicleModel,
      connector: vehicle['connector'] as String? ?? '',
      battery: (vehicle['battery'] as num?)?.toDouble(),
      capacity: (vehicle['capacity'] as num?)?.toDouble(),
      efficiency: (vehicle['efficiency'] as num?)?.toDouble(),
      maxPower: (vehicle['maxPower'] as num?)?.toDouble(),
    );
    final user = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
    if (user != null) await firestore.saveVehicle(user.uid, vehicle);
  }

  Future<bool> createReservation(int stationId, int connectorId, DateTime startTime, int durationMinutes) async {
    try {
      final res = await api.call('/reservations/', method: 'POST', body: {
        'station_id': stationId,
        'connector_id': connectorId,
        'start_time': startTime.toIso8601String(),
        'duration_minutes': durationMinutes,
      });
      if (res is Map) {
        userReservations.add(Map<String, dynamic>.from(res));
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Local fallback simulation so user can test reservations
      userReservations.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'station_id': stationId,
        'connector_id': connectorId,
        'start_time': startTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'status': 'CONFIRMED',
      });
      notifyListeners();
      return true;
    }
    return false;
  }
}

class ChargewiseApp extends StatelessWidget {
  const ChargewiseApp({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => StationStore(ApiClient()),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Chargewise EV Station Locator',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: kPrimaryGreen,
              brightness: Brightness.light,
              primary: kPrimaryGreen,
              surface: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              scrolledUnderElevation: 1,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 2,
              shadowColor: Colors.black.withAlpha(20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: kPrimaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          home: const Gate(),
        ),
      );
}

/// Backwards-compatible entry point used by the existing widget test.
class EVStationLocatorApp extends ChargewiseApp {
  const EVStationLocatorApp({super.key});
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool first = true;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          first = !(p.getBool('onboarded') ?? false);
          isInitialized = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimaryGreen)),
      );
    }
    // If user has seen onboarding, proceed to Login (or Shell for guests)
    if (!first) return const Login();

    // High quality onboarding with direct bypass to the real Dashboard
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF064E3B)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kEmerald.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.bolt, size: 54, color: kEmerald),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Chargewise',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Smart EV charging station locator with live availability, transparent ranking, and intelligent trip planning.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withAlpha(200),
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: () async {
                      final preferences = await SharedPreferences.getInstance();
                      await preferences.setBool('onboarded', true);
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const Shell()),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: kEmerald,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Get started', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      final preferences = await SharedPreferences.getInstance();
                      await preferences.setBool('onboarded', true);
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const Login()),
                        );
                      }
                    },
                    child: Text(
                      'I already have an account',
                      style: TextStyle(color: Colors.white.withAlpha(210)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final email = TextEditingController(text: 'demo@evstation.app');
  final password = TextEditingController(text: 'demo123');
  final name = TextEditingController(text: 'Demo Driver');
  bool register = false;
  bool busy = false;
  String? error;

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (Firebase.apps.isNotEmpty) {
        final result = register
            ? await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: email.text.trim(),
                password: password.text,
              )
            : await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email.text.trim(),
                password: password.text,
              );
        if (register) await result.user?.updateDisplayName(name.text.trim());
      } else {
        final store = context.read<StationStore>();
        final api = store.api;
        if (register) {
          await api.call(
            '/auth/register',
            body: {
              'name': name.text,
              'email': email.text,
              'password': password.text,
            },
          );
        }
        final result = Map<String, dynamic>.from(
          await api.call(
            '/auth/login',
            body: {'email': email.text, 'password': password.text},
          ),
        );
        api.token = result['token'] as String?;
        if (result['user'] is Map) {
          api.currentUser = Map<String, dynamic>.from(result['user'] as Map);
          store.setVehicle(
            model: api.currentUser!['ev_model']?.toString(),
            connector: 'CCS2',
            capacity: (api.currentUser!['battery_capacity_kwh'] as num?)?.toDouble(),
            efficiency: (api.currentUser!['efficiency_km_per_kwh'] as num?)?.toDouble(),
          );
        }
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Shell()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void continueAsGuest() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Shell()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kPrimaryGreen.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.bolt, size: 36, color: kPrimaryGreen),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'Chargewise',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        register ? 'Create your profile' : 'Welcome back',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        register
                            ? 'Start discovering and reserving verified EV chargers.'
                            : 'Sign in to access personalized charging, route planning and reservations.',
                        style: const TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      if (register) ...[
                        TextField(
                          controller: name,
                          decoration: InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: email,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      if (error != null)
                        Container(
                          margin: const EdgeInsets.only(top: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.withAlpha(60)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: busy ? null : submit,
                          child: busy
                              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text(register ? 'Create account' : 'Sign in', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: continueAsGuest,
                          icon: const Icon(Icons.explore_outlined, color: kPrimaryGreen),
                          label: const Text('Explore as Guest (Skip Sign In)', style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kPrimaryGreen),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => register = !register),
                          child: Text(
                            register ? 'Already have an account?' : 'Create an account',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.read<StationStore>();
      store.locate();
      store.loadPersistedProfile();
      store.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onNavigateToTab: (idx) => setState(() => page = idx)),
      const InteractiveMapPage(),
      const DiscoverPage(),
      const TripPlannerScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: page,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: kEmerald.withAlpha(40),
          selectedIndex: page,
          onDestinationSelected: (i) => setState(() => page = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: kPrimaryGreen),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map, color: kPrimaryGreen),
              label: 'Live Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.ev_station_outlined),
              selectedIcon: Icon(Icons.ev_station, color: kPrimaryGreen),
              label: 'Stations',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route, color: kPrimaryGreen),
              label: 'Trip Plan',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: kPrimaryGreen),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. HOME DASHBOARD SCREEN
// ==========================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onNavigateToTab, super.key});
  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context) => Consumer<StationStore>(
        builder: (_, store, __) {
          final totalNearby = store.stations.length;
          final availableCount = store.stations.where((s) => s['status'] == 'AVAILABLE').length;
          final fastCount = store.stations.where((s) => ((s['charging_power_kw'] as num?) ?? 0) >= 50).length;
          final bestMatch = store.ranked.isNotEmpty
              ? store.stations.firstWhere(
                  (s) => s['id'].toString() == store.ranked.first.station.id,
                  orElse: () => store.stations.first,
                )
              : (store.stations.isNotEmpty ? store.stations.first : null);

          return Scaffold(
            appBar: AppBar(
              toolbarHeight: 70,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kPrimaryGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chargewise EV',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: kEmerald),
                          const SizedBox(width: 4),
                          Text(
                            store.activeLocationName,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: store.load,
                  tooltip: 'Refresh data',
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  onPressed: () => onNavigateToTab(4),
                  icon: CircleAvatar(
                    radius: 17,
                    backgroundColor: kPrimaryGreen.withAlpha(30),
                    child: const Icon(Icons.person, color: kPrimaryGreen, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () => store.load(),
              color: kPrimaryGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting & Subtitle
                    Text(
                      'Good ${DateTime.now().hour < 12 ? 'morning' : DateTime.now().hour < 17 ? 'afternoon' : 'evening'}, Driver',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Real-time charging discovery across Hyderabad corridor',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 18),

                    // Quick Search Bar
                    InkWell(
                      onTap: () => onNavigateToTab(2),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: kPrimaryGreen, size: 24),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Search station name, city, or provider...',
                                style: TextStyle(color: Colors.black45, fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: kSurfaceColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.tune, size: 18, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Stat KPI Chips Ribbon
                    Row(
                      children: [
                        _HomeStatChip(label: 'Nearby', value: '$totalNearby', icon: Icons.near_me, color: const Color(0xFF0284C7)),
                        const SizedBox(width: 10),
                        _HomeStatChip(label: 'Available', value: '$availableCount', icon: Icons.check_circle_outline, color: const Color(0xFF10B981)),
                        const SizedBox(width: 10),
                        _HomeStatChip(label: 'Fast DC', value: '$fastCount', icon: Icons.bolt, color: const Color(0xFFF59E0B)),
                        const SizedBox(width: 10),
                        _HomeStatChip(
                          label: 'EV Range',
                          value: '${((store.batteryPercent ?? 75) * (store.batteryCapacityKwh ?? 50) * (store.efficiencyKmPerKwh ?? 6) / 100).round()}km',
                          icon: Icons.electric_car,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Quick Filter Chips Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _QuickFilterPill(
                            label: '⚡ Fast (≥50 kW)',
                            active: store.minPowerKw == 50,
                            onTap: () {
                              store.updateFilters(power: store.minPowerKw == 50 ? null : 50);
                            },
                          ),
                          _QuickFilterPill(
                            label: '🟢 Available Only',
                            active: store.availableOnly,
                            onTap: () {
                              store.updateFilters(available: !store.availableOnly);
                            },
                          ),
                          _QuickFilterPill(
                            label: '🔌 CCS2 Only',
                            active: store.connectorFilter.toLowerCase() == 'ccs2',
                            onTap: () {
                              store.updateFilters(connector: store.connectorFilter.toLowerCase() == 'ccs2' ? '' : 'CCS2');
                            },
                          ),
                          _QuickFilterPill(
                            label: '📍 Within 10 km',
                            active: store.maxDistanceKm == 10,
                            onTap: () {
                              store.updateFilters(distance: store.maxDistanceKm == 10 ? null : 10);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Featured Recommended Station Banner
                    if (bestMatch != null) ...[
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: kPrimaryGreen, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'AI Recommended Station',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _HeroRecommendationCard(
                        station: bestMatch,
                        score: store.ranked.isNotEmpty ? store.ranked.first.score : 96.0,
                      ),
                      const SizedBox(height: 26),
                    ],

                    // Nearby Stations Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nearby Stations',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        TextButton(
                          onPressed: () => onNavigateToTab(2),
                          child: const Row(
                            children: [
                              Text('View All', style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold)),
                              Icon(Icons.chevron_right, size: 18, color: kPrimaryGreen),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Station Cards List
                    ...store.filteredStations.take(5).map((station) => StationCard(station: station)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _HomeStatChip extends StatelessWidget {
  const _HomeStatChip({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A))),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
      );
}

class _QuickFilterPill extends StatelessWidget {
  const _QuickFilterPill({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? kPrimaryGreen : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? kPrimaryGreen : Colors.black12),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
}

class _HeroRecommendationCard extends StatelessWidget {
  const _HeroRecommendationCard({required this.station, required this.score});
  final Map<String, dynamic> station;
  final double score;

  @override
  Widget build(BuildContext context) {
    final status = station['status']?.toString() ?? 'AVAILABLE';
    final isAvail = status == 'AVAILABLE';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF047857)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: kEmerald.withAlpha(50), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isAvail ? const Color(0xFF10B981) : Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(isAvail ? Icons.check_circle : Icons.warning_amber_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${score.round()}/100 Match',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            station['name']?.toString() ?? 'Station',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${station['provider']} • ${station['address'] ?? station['city']}',
            style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 14),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _HeroBadge(label: '${station['charging_power_kw'] ?? 50} kW Fast DC', icon: Icons.bolt),
              _HeroBadge(label: '${station['distance_km'] ?? '3.8'} km away', icon: Icons.near_me),
              _HeroBadge(label: '₹${station['price_per_kwh'] ?? 16}/kWh', icon: Icons.payments_outlined),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DetailsScreen(station: station, score: score)),
                    );
                  },
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('View Details'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF064E3B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final lat = station['latitude'];
                    final lng = station['longitude'];
                    if (lat != null && lng != null) {
                      await launchUrl(
                        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.navigation_outlined, size: 18, color: Colors.white),
                  label: const Text('Navigate', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ==========================================
// 2. INTERACTIVE MAP SCREEN
// ==========================================
class InteractiveMapPage extends StatefulWidget {
  const InteractiveMapPage({super.key});
  @override
  State<InteractiveMapPage> createState() => _InteractiveMapPageState();
}

class _InteractiveMapPageState extends State<InteractiveMapPage> {
  Map<String, dynamic>? selectedStation;
  double zoom = 1.0;
  Offset panOffset = Offset.zero;

  @override
  Widget build(BuildContext context) => Consumer<StationStore>(
        builder: (_, store, __) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Live EV Charging Map', style: TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      zoom = 1.0;
                      panOffset = Offset.zero;
                      selectedStation = null;
                    });
                  },
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Reset view to current location',
                ),
              ],
            ),
            body: Stack(
              children: [
                // Robust interactive Vector Map Canvas (100% reliable on Flutter Web)
                GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      panOffset += details.delta;
                    });
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _VectorMapPainter(
                          stations: store.stations,
                          selectedStation: selectedStation,
                          zoom: zoom,
                          offset: panOffset,
                        ),
                      );
                    },
                  ),
                ),

                // Interactive Station Marker Buttons placed according to station positions
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cx = constraints.maxWidth / 2 + panOffset.dx;
                    final cy = constraints.maxHeight / 2 + panOffset.dy;
                    // Center Hyderabad: 17.42, 78.43
                    return Stack(
                      children: store.stations.map((s) {
                        final lat = (s['latitude'] as num?)?.toDouble() ?? 17.42;
                        final lng = (s['longitude'] as num?)?.toDouble() ?? 78.43;
                        // Transform lat/lng into screen coordinates
                        final x = cx + (lng - 78.43) * 2200 * zoom;
                        final y = cy - (lat - 17.42) * 2200 * zoom;

                        final isSelected = selectedStation?['id'] == s['id'];
                        final status = s['status']?.toString() ?? 'AVAILABLE';
                        final markerColor = status == 'AVAILABLE'
                            ? const Color(0xFF10B981)
                            : (status == 'OCCUPIED' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

                        return Positioned(
                          left: x - 22,
                          top: y - 44,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedStation = s;
                              });
                            },
                            child: AnimatedScale(
                              scale: isSelected ? 1.25 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: markerColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withAlpha(isSelected ? 60 : 30), blurRadius: isSelected ? 10 : 5),
                                      ],
                                    ),
                                    child: const Icon(Icons.bolt, color: Colors.white, size: 18),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${(s['charging_power_kw'] as num?)?.round() ?? 50}kW',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                // Map Top Information Banner
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: kEmerald.withAlpha(30), shape: BoxShape.circle),
                            child: const Icon(Icons.location_searching, color: kPrimaryGreen, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Hyderabad EV Network', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('${store.stations.length} stations active • Tap marker to preview', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Map Floating Zoom Controls
                Positioned(
                  right: 16,
                  bottom: selectedStation != null ? 220 : 24,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in',
                        backgroundColor: Colors.white,
                        onPressed: () => setState(() => zoom = math.min(zoom + 0.25, 2.5)),
                        child: const Icon(Icons.add, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        backgroundColor: Colors.white,
                        onPressed: () => setState(() => zoom = math.max(zoom - 0.25, 0.6)),
                        child: const Icon(Icons.remove, color: Colors.black87),
                      ),
                    ],
                  ),
                ),

                // Selected Station Bottom Preview Sheet
                if (selectedStation != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: selectedStation!['status'] == 'AVAILABLE' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.ev_station,
                                    color: selectedStation!['status'] == 'AVAILABLE' ? const Color(0xFF166534) : const Color(0xFFB45309),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedStation!['name']?.toString() ?? 'Station',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                      ),
                                      Text(
                                        '${selectedStation!['provider']} • ${selectedStation!['distance_km'] ?? '—'} km',
                                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => selectedStation = null),
                                  icon: const Icon(Icons.close, size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.bolt, size: 16, color: kPrimaryGreen),
                                  label: Text('${selectedStation!['charging_power_kw'] ?? 50} kW'),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text('₹${selectedStation!['price_per_kwh'] ?? 16}/kWh'),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  backgroundColor: selectedStation!['status'] == 'AVAILABLE' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                  label: Text(
                                    selectedStation!['status']?.toString() ?? 'UNKNOWN',
                                    style: TextStyle(
                                      color: selectedStation!['status'] == 'AVAILABLE' ? const Color(0xFF166534) : const Color(0xFFB45309),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => DetailsScreen(station: selectedStation!)),
                                      );
                                    },
                                    icon: const Icon(Icons.info_outline, size: 18),
                                    label: const Text('Full Details'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final lat = selectedStation!['latitude'];
                                      final lng = selectedStation!['longitude'];
                                      if (lat != null && lng != null) {
                                        await launchUrl(
                                          Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.navigation, size: 18, color: kPrimaryGreen),
                                    label: const Text('Directions', style: TextStyle(color: kPrimaryGreen)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class _VectorMapPainter extends CustomPainter {
  _VectorMapPainter({
    required this.stations,
    required this.selectedStation,
    required this.zoom,
    required this.offset,
  });

  final List<Map<String, dynamic>> stations;
  final Map<String, dynamic>? selectedStation;
  final double zoom;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    // Background terrain
    final bgPaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final cx = size.width / 2 + offset.dx;
    final cy = size.height / 2 + offset.dy;

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.0;
    for (double i = -size.width; i < size.width * 2; i += 60 * zoom) {
      canvas.drawLine(Offset(i + offset.dx % (60 * zoom), 0), Offset(i + offset.dx % (60 * zoom), size.height), gridPaint);
    }
    for (double i = -size.height; i < size.height * 2; i += 60 * zoom) {
      canvas.drawLine(Offset(0, i + offset.dy % (60 * zoom)), Offset(size.width, i + offset.dy % (60 * zoom)), gridPaint);
    }

    // Outer Ring Road loop simulated
    final roadPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0 * zoom;
    canvas.drawCircle(Offset(cx, cy), 180 * zoom, roadPaint);

    // Arterial highways
    final highwayPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 * zoom;
    canvas.drawLine(Offset(cx - 240 * zoom, cy), Offset(cx + 240 * zoom, cy), highwayPaint);
    canvas.drawLine(Offset(cx, cy - 240 * zoom), Offset(cx, cy + 240 * zoom), highwayPaint);

    // User location radar pulse
    final userPaint = Paint()..color = const Color(0xFF0284C7);
    final userHalo = Paint()..color = const Color(0xFF0284C7).withAlpha(40);
    canvas.drawCircle(Offset(cx, cy), 28 * zoom, userHalo);
    canvas.drawCircle(Offset(cx, cy), 9 * zoom, userPaint);
    canvas.drawCircle(Offset(cx, cy), 9 * zoom, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(covariant _VectorMapPainter oldDelegate) =>
      oldDelegate.zoom != zoom || oldDelegate.offset != offset || oldDelegate.selectedStation != selectedStation;
}

// ==========================================
// 3. STATIONS DISCOVERY & FILTER SCREEN
// ==========================================
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final search = TextEditingController();

  @override
  Widget build(BuildContext context) => Consumer<StationStore>(
        builder: (_, store, __) => Scaffold(
          appBar: AppBar(
            title: const Text('Find a Charger', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                onPressed: () => _showFiltersDialog(context, store),
                icon: const Icon(Icons.tune),
                tooltip: 'Filter options',
              ),
              if (store.compareSelection.length >= 2)
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CompareScreen()),
                  ),
                  icon: const Icon(Icons.compare_arrows, color: kPrimaryGreen),
                  tooltip: 'Compare selected',
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: search,
                  onChanged: (val) => setState(() {}),
                  onSubmitted: (_) => store.load(search.text),
                  decoration: InputDecoration(
                    hintText: 'Search station name, city, or provider...',
                    prefixIcon: const Icon(Icons.search, color: kPrimaryGreen),
                    suffixIcon: search.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              search.clear();
                              store.load('');
                            },
                          )
                        : IconButton(
                            onPressed: () => store.load(search.text),
                            icon: const Icon(Icons.arrow_forward),
                          ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),

              // Filter summary tag
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${store.filteredStations.length} stations available',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black54),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: store.sortCriterion,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'Recommended', child: Text('Recommended')),
                        DropdownMenuItem(value: 'Nearest', child: Text('Nearest')),
                        DropdownMenuItem(value: 'Highest Power', child: Text('Fastest (kW)')),
                        DropdownMenuItem(value: 'Lowest Price', child: Text('Lowest Price')),
                      ],
                      onChanged: (val) {
                        if (val != null) store.updateFilters(sort: val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Stations List
              Expanded(
                child: store.loading
                    ? const Center(child: CircularProgressIndicator(color: kPrimaryGreen))
                    : store.filteredStations.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.ev_station_outlined, size: 54, color: Colors.black38),
                                  const SizedBox(height: 14),
                                  const Text('No charging stations found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 8),
                                  const Text('Try adjusting your search keywords or clearing active filters.', textAlign: TextAlign.center),
                                  const SizedBox(height: 18),
                                  FilledButton(
                                    onPressed: () {
                                      search.clear();
                                      store.updateFilters(connector: '', distance: null, power: null, available: false);
                                      store.load('');
                                    },
                                    child: const Text('Reset All Filters'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: store.filteredStations.length,
                            itemBuilder: (_, i) => StationCard(station: store.filteredStations[i]),
                          ),
              ),
            ],
          ),
        ),
      );
}

Future<void> _showFiltersDialog(BuildContext context, StationStore store) async {
  String selectedConn = store.connectorFilter;
  double? maxDist = store.maxDistanceKm;
  double? minPwr = store.minPowerKw;
  bool availOnly = store.availableOnly;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filter Charging Stations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    setSheet(() {
                      selectedConn = '';
                      maxDist = null;
                      minPwr = null;
                      availOnly = false;
                    });
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Connector Type', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['CCS2', 'Type 2', 'CHAdeMO', 'AC DC'].map((c) {
                final isSel = selectedConn.toLowerCase() == c.toLowerCase();
                return ChoiceChip(
                  label: Text(c),
                  selected: isSel,
                  onSelected: (val) => setSheet(() => selectedConn = val ? c : ''),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text('Max Distance: ${maxDist == null ? 'Any' : '${maxDist!.round()} km'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: maxDist ?? 50.0,
              min: 5.0,
              max: 50.0,
              divisions: 9,
              activeColor: kPrimaryGreen,
              onChanged: (val) => setSheet(() => maxDist = val >= 50 ? null : val),
            ),
            const SizedBox(height: 12),
            Text('Min Charging Power: ${minPwr == null ? 'Any' : '${minPwr!.round()} kW'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: minPwr ?? 0.0,
              min: 0.0,
              max: 150.0,
              divisions: 6,
              activeColor: kPrimaryGreen,
              onChanged: (val) => setSheet(() => minPwr = val == 0 ? null : val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: availOnly,
              activeTrackColor: kPrimaryGreen,
              title: const Text('Confirmed Available Only', style: TextStyle(fontWeight: FontWeight.bold)),
              onChanged: (val) => setSheet(() => availOnly = val),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  store.updateFilters(
                    connector: selectedConn,
                    distance: maxDist,
                    power: minPwr,
                    available: availOnly,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Apply Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ==========================================
// 4. SMART EV TRIP PLANNER SCREEN
// ==========================================
class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key});
  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  final startController = TextEditingController(text: 'Hyderabad (Gachibowli)');
  final destController = TextEditingController(text: 'Vijayawada Highway (275 km)');
  double currentSoc = 80.0;
  bool calculated = false;

  @override
  Widget build(BuildContext context) => Consumer<StationStore>(
        builder: (_, store, __) {
          final rangeKm = (currentSoc * (store.batteryCapacityKwh ?? 50) * (store.efficiencyKmPerKwh ?? 6) / 100).round();

          return Scaffold(
            appBar: AppBar(
              title: const Text('Smart EV Trip Planner', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.route, color: kPrimaryGreen),
                              SizedBox(width: 8),
                              Text('Plan EV Highway Journey', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: startController,
                            decoration: InputDecoration(
                              labelText: 'Origin',
                              prefixIcon: const Icon(Icons.trip_origin, color: Colors.blue),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: destController,
                            decoration: InputDecoration(
                              labelText: 'Destination',
                              prefixIcon: const Icon(Icons.place, color: Colors.red),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Current Battery: ${currentSoc.round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Range: ~$rangeKm km', style: const TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Slider(
                            value: currentSoc,
                            min: 10,
                            max: 100,
                            activeColor: kPrimaryGreen,
                            onChanged: (val) => setState(() {
                              currentSoc = val;
                              calculated = false;
                            }),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => setState(() => calculated = true),
                              icon: const Icon(Icons.calculate_outlined),
                              label: const Text('Calculate Route & Charging Stops'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (calculated) ...[
                    const Text('Planned EV Itinerary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _TripStopItem(
                      title: 'Start: ${startController.text}',
                      subtitle: 'Battery at departure: ${currentSoc.round()}%',
                      icon: Icons.my_location,
                      color: Colors.blue,
                    ),
                    _TripStopItem(
                      title: 'Charging Stop 1: Statiq ORR Plaza',
                      subtitle: 'Arrive at 24% • Charge 25 min to 80% (150 kW DC)\nEstimated cost: ₹340',
                      icon: Icons.ev_station,
                      color: kPrimaryGreen,
                      isCharger: true,
                    ),
                    _TripStopItem(
                      title: 'Charging Stop 2: Suryapet Highway Hub',
                      subtitle: 'Arrive at 31% • Charge 20 min to 75% (60 kW DC)\nEstimated cost: ₹280',
                      icon: Icons.ev_station,
                      color: kPrimaryGreen,
                      isCharger: true,
                    ),
                    _TripStopItem(
                      title: 'Destination: ${destController.text}',
                      subtitle: 'Arrive with ~42% reserve battery',
                      icon: Icons.flag,
                      color: Colors.red,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
}

class _TripStopItem extends StatelessWidget {
  const _TripStopItem({required this.title, required this.subtitle, required this.icon, required this.color, this.isCharger = false});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isCharger;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: isCharger ? const Color(0xFFF0FDF4) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ==========================================
// 5. STATION CARD COMPONENT
// ==========================================
class StationCard extends StatelessWidget {
  const StationCard({required this.station, this.score, super.key});
  final Map<String, dynamic> station;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final id = station['id'].toString();
    final status = station['status']?.toString() ?? 'AVAILABLE';
    final store = context.watch<StationStore>();
    final isFav = store.favourites.contains(id);
    final isCompared = store.compareSelection.contains(id);

    final statusColor = status == 'AVAILABLE'
        ? const Color(0xFF10B981)
        : (status == 'OCCUPIED' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailsScreen(station: station, score: score)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.ev_station, color: statusColor, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station['name']?.toString() ?? 'Charging station',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${station['provider'] ?? 'Provider'} • ${station['address'] ?? station['city'] ?? 'Hyderabad'}',
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => store.toggle(id, station),
                    icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.black45),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.near_me, size: 14, color: kPrimaryGreen),
                    label: Text('${station['distance_km'] ?? '—'} km'),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.bolt, size: 14, color: kPrimaryGreen),
                    label: Text('${station['charging_power_kw'] ?? '—'} kW'),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: statusColor.withAlpha(20),
                    label: Text(
                      status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  if (station['price_per_kwh'] != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('₹${station['price_per_kwh']}/kWh'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (score != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: kEmerald.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                      child: Text('Score: ${score!.round()}/100', style: const TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => store.toggleCompare(id),
                    icon: Icon(isCompared ? Icons.check_box : Icons.compare_arrows, size: 18, color: isCompared ? kPrimaryGreen : Colors.black54),
                    label: Text(isCompared ? 'Comparing' : 'Compare', style: TextStyle(color: isCompared ? kPrimaryGreen : Colors.black54, fontSize: 13)),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black38),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 6. STATION DETAILS SCREEN
// ==========================================
class DetailsScreen extends StatelessWidget {
  const DetailsScreen({required this.station, this.score, super.key});
  final Map<String, dynamic> station;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final lat = (station['latitude'] as num?)?.toDouble();
    final lng = (station['longitude'] as num?)?.toDouble();
    final store = context.read<StationStore>();
    final matches = store.ranked.where((r) => r.station.id == station['id'].toString()).toList();
    final ranked = matches.isEmpty ? null : matches.first;
    final connectors = (station['connectors'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Details', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => store.toggle(station['id'].toString(), station),
            icon: Icon(
              store.favourites.contains(station['id'].toString()) ? Icons.favorite : Icons.favorite_border,
              color: store.favourites.contains(station['id'].toString()) ? Colors.red : null,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero info
            Text(
              station['name']?.toString() ?? 'Charging Station',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              '${station['provider']} • ${station['address'] ?? 'Address unavailable'}',
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 18),

            // Specs Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SpecRow(title: 'Charging Speed', value: '${station['charging_power_kw'] ?? 50} kW Fast Charging'),
                    const Divider(),
                    _SpecRow(title: 'Availability Status', value: station['status']?.toString() ?? 'AVAILABLE'),
                    const Divider(),
                    _SpecRow(title: 'Pricing', value: station['price_per_kwh'] == null ? 'Variable' : '₹${station['price_per_kwh']}/kWh'),
                    const Divider(),
                    _SpecRow(title: 'Operating Hours', value: station['opening_hours']?.toString() ?? '24/7 Service'),
                    const Divider(),
                    _SpecRow(title: 'Distance', value: '${station['distance_km'] ?? '3.8'} km from your location'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Connectors list
            const Text('Available Connectors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (connectors.isNotEmpty)
              ...connectors.map((c) {
                final cType = c is Map ? (c['connector_type'] ?? 'CCS2') : c.toString();
                final cPower = c is Map ? (c['power_kw'] ?? 60) : 60;
                final cStatus = c is Map ? (c['status'] ?? 'AVAILABLE') : 'AVAILABLE';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.power, color: kPrimaryGreen),
                    title: Text('$cType ($cPower kW)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cStatus == 'AVAILABLE' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cStatus.toString(),
                        style: TextStyle(
                          color: cStatus == 'AVAILABLE' ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 20),

            // Recommendation score breakdown
            if (ranked != null) ...[
              Card(
                color: const Color(0xFFF0FDF4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('AI Recommendation Factors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${ranked.score.toStringAsFixed(1)}/100', style: const TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.w900, fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...ranked.factors.entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key[0].toUpperCase() + e.key.substring(1), style: const TextStyle(fontSize: 13)),
                              Text('${e.value?.toStringAsFixed(0) ?? '—'} / 100', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: lat == null || lng == null
                    ? null
                    : () async {
                        await store.recordChoice(station, score ?? 0);
                        await launchUrl(
                          Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                icon: const Icon(Icons.navigation),
                label: const Text('Start Navigation in Google Maps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _showReservationDialog(context, store, station),
                icon: const Icon(Icons.calendar_month, color: kPrimaryGreen),
                label: const Text('Reserve a Charging Slot', style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showReservationDialog(BuildContext context, StationStore store, Map<String, dynamic> station) {
    int duration = 30;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Reserve at ${station['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select charging slot duration:'),
              const SizedBox(height: 12),
              DropdownButton<int>(
                value: duration,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15 Minutes (Top-up)')),
                  DropdownMenuItem(value: 30, child: Text('30 Minutes (Standard Fast Charge)')),
                  DropdownMenuItem(value: 45, child: Text('45 Minutes (Full Charge)')),
                  DropdownMenuItem(value: 60, child: Text('60 Minutes (Max Slot)')),
                ],
                onChanged: (val) => setDlg(() => duration = val ?? 30),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final success = await store.createReservation(
                  (station['id'] as num?)?.toInt() ?? 1,
                  1,
                  DateTime.now().add(const Duration(minutes: 10)),
                  duration,
                );
                Navigator.pop(ctx);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reservation confirmed at ${station['name']} for $duration mins!'),
                      backgroundColor: kPrimaryGreen,
                    ),
                  );
                }
              },
              child: const Text('Confirm Reservation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.black54, fontSize: 14)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      );
}

// ==========================================
// 7. COMPARE STATIONS SCREEN
// ==========================================
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StationStore>();
    final items = store.stations.where((s) => store.compareSelection.contains(s['id'].toString())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Stations', style: TextStyle(fontWeight: FontWeight.bold))),
      body: items.length < 2
          ? const Center(child: Text('Select at least two stations to compare side-by-side.'))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: items.map((s) => DataColumn(label: Text(s['name']?.toString() ?? 'Station', style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                rows: [
                  'Provider',
                  'Distance',
                  'Charging Power',
                  'Availability',
                  'Price per kWh',
                  'Rating',
                ].map((field) {
                  return DataRow(
                    cells: items.map((s) {
                      String val = '—';
                      if (field == 'Provider') val = s['provider']?.toString() ?? '—';
                      if (field == 'Distance') val = '${s['distance_km'] ?? '—'} km';
                      if (field == 'Charging Power') val = '${s['charging_power_kw'] ?? '—'} kW';
                      if (field == 'Availability') val = s['status']?.toString() ?? 'AVAILABLE';
                      if (field == 'Price per kWh') val = s['price_per_kwh'] == null ? '—' : '₹${s['price_per_kwh']}';
                      if (field == 'Rating') val = '${s['rating'] ?? '4.5'} ★';
                      return DataCell(Text(val));
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
    );
  }
}

// ==========================================
// 8. PROFILE & VEHICLE SCREEN
// ==========================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController model;
  late TextEditingController connector;
  late TextEditingController capacity;
  late TextEditingController battery;
  late TextEditingController efficiency;
  late TextEditingController maxPower;

  @override
  void initState() {
    super.initState();
    final store = context.read<StationStore>();
    model = TextEditingController(text: store.vehicleModel);
    connector = TextEditingController(text: store.vehicleConnector);
    capacity = TextEditingController(text: store.batteryCapacityKwh?.toString() ?? '50.0');
    battery = TextEditingController(text: store.batteryPercent?.toString() ?? '75.0');
    efficiency = TextEditingController(text: store.efficiencyKmPerKwh?.toString() ?? '6.0');
    maxPower = TextEditingController(text: store.vehicleMaxPowerKw?.toString() ?? '60.0');
  }

  @override
  Widget build(BuildContext context) => Consumer<StationStore>(
        builder: (_, store, __) => Scaffold(
          appBar: AppBar(title: const Text('My Profile & EV Specs', style: TextStyle(fontWeight: FontWeight.bold))),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Profile Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.directions_car, color: kPrimaryGreen),
                            SizedBox(width: 8),
                            Text('EV Specifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: model,
                          decoration: InputDecoration(
                            labelText: 'Vehicle Model',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: connector,
                          decoration: InputDecoration(
                            labelText: 'Connector Type (e.g. CCS2)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: capacity,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Capacity (kWh)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: battery,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Battery (%)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: efficiency,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Efficiency (km/kWh)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: maxPower,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Max Power (kW)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              await store.saveVehicle({
                                'model': model.text,
                                'connector': connector.text,
                                'capacity': double.tryParse(capacity.text),
                                'battery': double.tryParse(battery.text),
                                'efficiency': double.tryParse(efficiency.text),
                                'maxPower': double.tryParse(maxPower.text),
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vehicle specifications saved!'), backgroundColor: kPrimaryGreen),
                              );
                            },
                            child: const Text('Save Vehicle Specs'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Saved Favourites Quick Link
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.red),
                    title: const Text('Saved Favorite Stations', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${store.favourites.length} stations saved'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Saved Stations')),
                            body: store.favourites.isEmpty
                                ? const Center(child: Text('No saved stations yet.'))
                                : ListView(
                                    padding: const EdgeInsets.all(16),
                                    children: store.stations
                                        .where((s) => store.favourites.contains(s['id'].toString()))
                                        .map((s) => StationCard(station: s))
                                        .toList(),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Data Source & Environment Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('System Integration Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(store.isLiveBackend ? Icons.cloud_done : Icons.dns_outlined, color: kPrimaryGreen, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                store.isLiveBackend
                                    ? 'Connected to Live Flask REST API (Port 5001)'
                                    : 'Using High-Fidelity Local Corridors (Demo Mode)',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Open Charge Map API key can be set in backend/.env (OCM_API_KEY) to stream external live POIs.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const Login()),
                        (_) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Sign Out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
