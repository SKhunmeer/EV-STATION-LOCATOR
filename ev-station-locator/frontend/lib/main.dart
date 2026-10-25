// The existing single-file UI is intentionally kept intact while the project
// is stabilized; these style lints are tracked separately from correctness.
// ignore_for_file: prefer_interpolation_to_compose_strings, unnecessary_underscores, use_build_context_synchronously, curly_braces_in_flow_control_structures
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/ranking.dart';
import 'services/firestore_repository.dart';

const green = Color(0xFF087F5B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Firebase configuration is optional for local/API-only runs. Do not
    // block the entire frontend when a platform has no Firebase options.
    // Web builds do not include generated Firebase options in this repository;
    // skip initialization there so the API-only experience can still render.
    if (!kIsWeb) {
      await Firebase.initializeApp().timeout(const Duration(seconds: 2));
    }
  } catch (_) {}
  runApp(const ChargewiseApp());
}

class ApiClient {
  final String _configuredBaseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5000/api',
  );
  String? token;
  String get baseUrl {
    final value = _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    return value.endsWith('/api') ? value : '$value/api';
  }

  Future<dynamic> call(String path, {Map<String, dynamic>? body}) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse(baseUrl + path);
    final response = body == null
        ? await http.get(uri, headers: headers)
        : await http.post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        throw Exception('The server returned an invalid response');
      }
    }
    if (response.statusCode >= 400)
      throw Exception(
        data is Map
            ? '${data['error'] ?? 'Request failed'} (${response.statusCode})'
            : 'Request failed (${response.statusCode}) at $uri',
      );
    return data;
  }
}

class StationStore extends ChangeNotifier {
  StationStore(this.api);
  final ApiClient api;
  List<Map<String, dynamic>> stations = [];
  List<RankedStation> ranked = [];
  final Set<String> favourites = {};
  final Set<String> compareSelection = {};
  final FirestoreRepository firestore = FirestoreRepository();
  String connectorFilter = '';
  double? maxDistanceKm;
  double? minPowerKw;
  bool availableOnly = false;
  String vehicleConnector = '';
  double? batteryPercent;
  double? batteryCapacityKwh;
  double? efficiencyKmPerKwh;
  double? vehicleMaxPowerKw;
  RankingWeights rankingWeights = const RankingWeights();
  String personalizationNote = 'New-user weights';
  bool loading = false;
  String? error;
  Position? position;
  Future<void> load([String query = '']) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final raw = await api.call(
        '/stations/?q=' + Uri.encodeQueryComponent(query),
      ) as List;
      stations = raw.map((x) => Map<String, dynamic>.from(x as Map)).toList();
      await _loadPersonalization();
      _rank();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadPersistedProfile() async {
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      favourites.addAll(
        (await firestore.favourites(user.uid))
            .map((item) => (item['stationId'] ?? item['id']).toString()),
      );
      final vehicle = await firestore.primaryVehicle(user.uid);
      if (vehicle != null) {
        setVehicle(
          connector: vehicle['connector'] as String? ?? '',
          battery: (vehicle['battery'] as num?)?.toDouble(),
          capacity: (vehicle['capacity'] as num?)?.toDouble(),
          efficiency: (vehicle['efficiency'] as num?)?.toDouble(),
          maxPower: (vehicle['maxPower'] as num?)?.toDouble(),
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  List<Map<String, dynamic>> get filteredStations => stations.where((s) {
    final distance = (s['distance_km'] as num?)?.toDouble();
    final power = (s['charging_power_kw'] as num?)?.toDouble();
    final connectors = ((s['connectors'] as List?) ?? []).map(
      (c) => c is Map
          ? c['connector_type'].toString().toLowerCase()
          : c.toString().toLowerCase(),
    );
    if (maxDistanceKm != null &&
        (distance == null || distance > maxDistanceKm!))
      return false;
    if (minPowerKw != null && (power == null || power < minPowerKw!))
      return false;
    if (connectorFilter.isNotEmpty &&
        !connectors.any((c) => c.contains(connectorFilter.toLowerCase())))
      return false;
    if (availableOnly && s['status'] != 'AVAILABLE') return false;
    return true;
  }).toList();
  void _rank() {
    ranked = StationRanker.rank(
      stations.map(
        (s) => StationCandidate(
          id: s['id'].toString(),
          distanceKm: (s['distance_km'] as num?)?.toDouble() ?? 999,
          connectorTypes: ((s['connectors'] as List?) ?? [])
              .map(
                (c) => c is Map ? c['connector_type'].toString() : c.toString(),
              )
              .toList(),
          maxPowerKw: (s['charging_power_kw'] as num?)?.toDouble() ?? 0,
          availableConnectors: (s['available_connectors'] as num?)?.toInt(),
          totalConnectors: (s['total_connectors'] as num?)?.toInt(),
          pricePerKwh: (s['price_per_kwh'] as num?)?.toDouble(),
          rating: (s['rating'] as num?)?.toDouble(),
          reviewCount: (s['review_count'] as num?)?.toInt() ?? 0,
          availabilityUpdatedAt: DateTime.tryParse(
            s['availability_updated_at']?.toString() ?? '',
          ),
        ),
      ),
      RankingContext(
        requiredConnectors: vehicleConnector.isEmpty
            ? const []
            : [vehicleConnector],
        batteryPercent: batteryPercent,
        batteryCapacityKwh: batteryCapacityKwh,
        efficiencyKmPerKwh: efficiencyKmPerKwh,
        vehicleMaxPowerKw: vehicleMaxPowerKw,
        weights: rankingWeights,
      ),
    );
  }

  Future<void> _loadPersonalization() async {
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final choices = await firestore.recentChoices(user.uid);
      if (choices.length < 3) return;
      final distances = choices
          .map((c) => (c['distanceKm'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      final powers = choices
          .map((c) => (c['powerKw'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      final prices = choices
          .map((c) => (c['pricePerKwh'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      var distanceWeight = .15, speedWeight = .15, priceWeight = .10;
      if (distances.isNotEmpty &&
          distances.reduce((a, b) => a + b) / distances.length <= 10)
        distanceWeight += .04;
      if (powers.isNotEmpty &&
          powers.reduce((a, b) => a + b) / powers.length >= 100)
        speedWeight += .04;
      if (prices.isNotEmpty &&
          prices.reduce((a, b) => a + b) / prices.length <= 20)
        priceWeight += .03;
      rankingWeights = RankingWeights(
        distance: distanceWeight,
        speed: speedWeight,
        price: priceWeight,
      );
      personalizationNote =
          'Adjusted within bounded limits from recent choices';
    } catch (_) {}
  }

  void updateFilters({
    String? connector,
    double? distance,
    double? power,
    bool? available,
  }) {
    connectorFilter = connector ?? connectorFilter;
    maxDistanceKm = distance;
    minPowerKw = power;
    availableOnly = available ?? availableOnly;
    notifyListeners();
  }

  void setVehicle({
    required String connector,
    double? battery,
    double? capacity,
    double? efficiency,
    double? maxPower,
  }) {
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
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;
      position = await Geolocator.getCurrentPosition();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggle(String id, [Map<String, dynamic>? station]) async {
    final adding = !favourites.contains(id);
    adding ? favourites.add(id) : favourites.remove(id);
    notifyListeners();
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (adding) {
        await firestore.setFavourite(
          user.uid,
          id,
          station ?? {'stationId': id},
        );
      } else {
        await firestore.removeFavourite(user.uid, id);
      }
    }
  }

  void toggleCompare(String id) {
    compareSelection.contains(id)
        ? compareSelection.remove(id)
        : compareSelection.add(id);
    notifyListeners();
  }

  Future<void> recordChoice(Map<String, dynamic> station, double score) async {
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    if (user != null)
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

  Future<void> saveVehicle(Map<String, dynamic> vehicle) async {
    setVehicle(
      connector: vehicle['connector'] as String? ?? '',
      battery: (vehicle['battery'] as num?)?.toDouble(),
      capacity: (vehicle['capacity'] as num?)?.toDouble(),
      efficiency: (vehicle['efficiency'] as num?)?.toDouble(),
      maxPower: (vehicle['maxPower'] as num?)?.toDouble(),
    );
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    if (user != null) await firestore.saveVehicle(user.uid, vehicle);
  }
}

class ChargewiseApp extends StatelessWidget {
  const ChargewiseApp({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => StationStore(ApiClient()),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chargewise',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => first = !(p.getBool('onboarded') ?? false));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!first) return const Login();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Icon(Icons.bolt, size: 72, color: green),
              Text(
                'Chargewise',
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('Find the right charger before you need it.'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final preferences = await SharedPreferences.getInstance();
                    await preferences.setBool('onboarded', true);
                    if (mounted) setState(() => first = false);
                  },
                  child: const Text('Get started'),
                ),
              ),
            ],
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
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool register = false, busy = false;
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
        final api = context.read<StationStore>().api;
        if (register)
          await api.call(
            '/auth/register',
            body: {
              'name': name.text,
              'email': email.text,
              'password': password.text,
            },
          );
        final result = Map<String, dynamic>.from(
          await api.call(
            '/auth/login',
            body: {'email': email.text, 'password': password.text},
          ),
        );
        api.token = result['token'] as String?;
      }
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Shell()),
        );
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bolt, size: 44, color: green),
                  const SizedBox(height: 18),
                  Text(
                    register ? 'Create your profile' : 'Welcome back',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Personalized charging, without the guesswork.'),
                  const SizedBox(height: 24),
                  if (register) ...[
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : submit,
                      child: busy
                          ? const CircularProgressIndicator()
                          : Text(register ? 'Create account' : 'Sign in'),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => register = !register),
                      child: Text(
                        register
                            ? 'Already have an account?'
                            : 'Create an account',
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
    const pages = [MapPage(), Discover(), ForYou(), Profile()];
    return Scaffold(
      body: pages[page],
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (i) => setState(() => page = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Discover'),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            label: 'For you',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key});
  @override
  Widget build(BuildContext context) => Consumer<StationStore>(
    builder: (_, store, __) {
      final center = store.position == null
          ? const LatLng(17.4065, 78.4772)
          : LatLng(store.position!.latitude, store.position!.longitude);
      final markers = store.stations
          .map((s) {
            final lat = (s['latitude'] as num?)?.toDouble(),
                lng = (s['longitude'] as num?)?.toDouble();
            return lat == null || lng == null
                ? null
                : Marker(
                    markerId: MarkerId(s['id'].toString()),
                    position: LatLng(lat, lng),
                    infoWindow: InfoWindow(
                      title: s['name']?.toString() ?? 'Station',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => Details(station: s)),
                    ),
                  );
          })
          .whereType<Marker>()
          .toSet();
      return SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 11),
              myLocationEnabled: store.position != null,
              markers: markers,
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: green),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Live charging map',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(store.stations.length.toString() + ' stations'),
                    ],
                  ),
                ),
              ),
            ),
            if (store.error != null)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Card(
                  child: ListTile(
                    title: const Text('Live data unavailable'),
                    subtitle: Text(store.error!),
                    trailing: IconButton(
                      onPressed: store.load,
                      icon: const Icon(Icons.refresh),
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

class Discover extends StatefulWidget {
  const Discover({super.key});
  @override
  State<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<Discover> {
  final search = TextEditingController();
  @override
  Widget build(BuildContext context) => Consumer<StationStore>(
    builder: (_, store, __) => Scaffold(
      appBar: AppBar(
        title: const Text('Find a charger'),
        actions: [
          IconButton(
            onPressed: () => _showFilters(context, store),
            icon: const Icon(Icons.tune),
          ),
          if (store.compareSelection.length >= 2)
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompareScreen()),
              ),
              icon: const Icon(Icons.compare_arrows),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: search,
              onSubmitted: (_) => store.load(search.text),
              decoration: InputDecoration(
                hintText: 'Search station, city, or network',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () => store.load(search.text),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          Expanded(
            child: store.loading
                ? const Center(child: CircularProgressIndicator())
                : store.filteredStations.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                store.error == null
                                    ? Icons.ev_station_outlined
                                    : Icons.cloud_off_outlined,
                                size: 52,
                                color: Colors.black45,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                store.error == null
                                    ? 'No charging stations found'
                                    : 'Could not load charging stations',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                store.error == null
                                    ? 'Try a different search or clear your filters.'
                                    : store.error!,
                                textAlign: TextAlign.center,
                              ),
                              if (store.error != null) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: store.load,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: store.filteredStations.length,
                        itemBuilder: (_, i) =>
                            StationCard(station: store.filteredStations[i]),
                      ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showFilters(BuildContext context, StationStore store) async {
  final connector = TextEditingController(text: store.connectorFilter);
  final distance = TextEditingController(
    text: store.maxDistanceKm?.toString() ?? '',
  );
  final power = TextEditingController(text: store.minPowerKw?.toString() ?? '');
  var available = store.availableOnly;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (context, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: connector,
              decoration: const InputDecoration(labelText: 'Connector type'),
            ),
            TextField(
              controller: distance,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maximum distance (km)',
              ),
            ),
            TextField(
              controller: power,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum power (kW)',
              ),
            ),
            SwitchListTile(
              value: available,
              onChanged: (value) => setSheet(() => available = value),
              title: const Text('Confirmed available only'),
            ),
            FilledButton(
              onPressed: () {
                store.updateFilters(
                  connector: connector.text,
                  distance: double.tryParse(distance.text),
                  power: double.tryParse(power.text),
                  available: available,
                );
                Navigator.pop(context);
              },
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    ),
  );
}

class ForYou extends StatelessWidget {
  const ForYou({super.key});
  @override
  Widget build(BuildContext context) => Consumer<StationStore>(
    builder: (_, store, __) => Scaffold(
      appBar: AppBar(title: const Text('Recommended for you')),
      body: store.ranked.isEmpty
          ? const Center(child: Text('No eligible recommendation yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Best match',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ranked by compatibility, availability, distance, speed, price, ratings, and battery suitability.',
                ),
                const SizedBox(height: 8),
                Text(
                  store.personalizationNote,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                ...store.ranked
                    .take(5)
                    .map(
                      (r) => StationCard(
                        station: store.stations.firstWhere(
                          (s) => s['id'].toString() == r.station.id,
                        ),
                        score: r.score,
                      ),
                    ),
              ],
            ),
    ),
  );
}

class StationCard extends StatelessWidget {
  const StationCard({required this.station, this.score, super.key});
  final Map<String, dynamic> station;
  final double? score;
  @override
  Widget build(BuildContext context) {
    final id = station['id'].toString(),
        status = station['status']?.toString() ?? 'UNKNOWN',
        store = context.watch<StationStore>();
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Details(station: station, score: score),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status == 'AVAILABLE'
                        ? Icons.ev_station
                        : Icons.help_outline,
                    color: status == 'AVAILABLE' ? green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      station['name']?.toString() ?? 'Charging station',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (score != null)
                    Text(
                      score!.round().toString() + '/100',
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              Text(
                (station['provider']?.toString() ?? 'Provider') +
                    ' • ' +
                    (station['city']?.toString() ?? 'Location unavailable'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(
                      (station['distance_km']?.toString() ?? '—') + ' km',
                    ),
                  ),
                  Chip(
                    label: Text(
                      (station['charging_power_kw']?.toString() ?? '—') + ' kW',
                    ),
                  ),
                  Chip(
                    label: Text(
                      status == 'UNKNOWN' ? 'Availability unknown' : status,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    station['price_per_kwh'] == null
                        ? 'Price unavailable'
                        : '₹' + station['price_per_kwh'].toString() + '/kWh',
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => store.toggle(id, station),
                    icon: Icon(
                      store.favourites.contains(id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: Colors.red,
                    ),
                  ),
                  IconButton(
                    onPressed: () => store.toggleCompare(id),
                    icon: Icon(
                      store.compareSelection.contains(id)
                          ? Icons.check_box
                          : Icons.compare_arrows,
                    ),
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

class Details extends StatelessWidget {
  const Details({required this.station, this.score, super.key});
  final Map<String, dynamic> station;
  final double? score;
  @override
  Widget build(BuildContext context) {
    final lat = (station['latitude'] as num?)?.toDouble(),
        lng = (station['longitude'] as num?)?.toDouble(),
        store = context.read<StationStore>(),
        matches = store.ranked
            .where((r) => r.station.id == station['id'].toString())
            .toList(),
        ranked = matches.isEmpty ? null : matches.first;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Station details'),
        actions: [
          IconButton(
            onPressed: () => store.toggleCompare(station['id'].toString()),
            icon: const Icon(Icons.compare_arrows),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            station['name']?.toString() ?? 'Station',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(station['address']?.toString() ?? 'Address unavailable'),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Power'),
                  subtitle: Text(
                    (station['charging_power_kw']?.toString() ?? 'Unknown') +
                        ' kW',
                  ),
                ),
                ListTile(
                  title: const Text('Availability'),
                  subtitle: Text(
                    (station['status']?.toString() ?? 'Unknown') +
                        ' — live freshness is not supplied by this provider',
                  ),
                ),
                ListTile(
                  title: const Text('Congestion'),
                  subtitle: Text(
                    station['congestion']?.toString() ??
                        'Congestion data unavailable',
                  ),
                ),
                ListTile(
                  title: const Text('Connectors'),
                  subtitle: Text(
                    (station['connectors'] as List? ?? [])
                        .map(
                          (c) => c is Map
                              ? c['connector_type'].toString()
                              : c.toString(),
                        )
                        .join(', '),
                  ),
                ),
                ListTile(
                  title: const Text('Price'),
                  subtitle: Text(
                    station['price_per_kwh'] == null
                        ? 'Unknown'
                        : '₹' + station['price_per_kwh'].toString() + '/kWh',
                  ),
                ),
                ListTile(
                  title: const Text('Rating'),
                  subtitle: Text(
                    station['rating']?.toString() ?? 'No verified rating',
                  ),
                ),
              ],
            ),
          ),
          if (Firebase.apps.isNotEmpty)
            ReviewSummary(stationId: station['id'].toString()),
          if (ranked != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommendation score: ' +
                          ranked.score.toStringAsFixed(1) +
                          '/100',
                    ),
                    ...ranked.factors.entries.map(
                      (e) => Text(
                        e.key +
                            ': ' +
                            (e.value?.toStringAsFixed(0) ?? 'unknown'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: lat == null || lng == null
                ? null
                : () async {
                    await store.recordChoice(station, score ?? 0);
                    await launchUrl(
                      Uri.parse(
                        'https://www.google.com/maps/dir/?api=1&destination=' +
                            lat.toString() +
                            ',' +
                            lng.toString(),
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                  },
            icon: const Icon(Icons.navigation),
            label: const Text('Start navigation'),
          ),
          OutlinedButton.icon(
            onPressed: () => _review(context, store),
            icon: const Icon(Icons.star_outline),
            label: const Text('Rate this station'),
          ),
        ],
      ),
    );
  }

  Future<void> _review(BuildContext context, StationStore store) async {
    var rating = 5;
    final reviewText = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Your station rating'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: rating,
                items: [1, 2, 3, 4, 5]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value stars'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => rating = value ?? 5),
              ),
              TextField(
                controller: reviewText,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Review'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final user = Firebase.apps.isEmpty
                    ? null
                    : FirebaseAuth.instance.currentUser;
                if (user != null)
                  await store.firestore.addReview(
                    user.uid,
                    station['id'].toString(),
                    rating,
                    reviewText.text,
                  );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<StationStore>();
    final items = store.stations
        .where((s) => store.compareSelection.contains(s['id'].toString()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Compare stations')),
      body: items.length < 2
          ? const Center(
              child: Text(
                'Select at least two stations using the compare icon.',
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: items
                    .map(
                      (s) => DataColumn(
                        label: Text(s['name']?.toString() ?? 'Station'),
                      ),
                    )
                    .toList(),
                rows:
                    [
                          'Distance',
                          'Compatibility',
                          'Power',
                          'Availability',
                          'Price',
                          'Rating',
                        ]
                        .map(
                          (field) => DataRow(
                            cells: items
                                .map((s) => DataCell(Text(_value(s, field))))
                                .toList(),
                          ),
                        )
                        .toList(),
              ),
            ),
    );
  }

  static String _value(Map<String, dynamic> station, String field) {
    if (field == 'Distance')
      return (station['distance_km']?.toString() ?? 'Unknown') + ' km';
    if (field == 'Power')
      return (station['charging_power_kw']?.toString() ?? 'Unknown') + ' kW';
    if (field == 'Price')
      return station['price_per_kwh'] == null
          ? 'Unknown'
          : '₹' + station['price_per_kwh'].toString();
    if (field == 'Rating') return station['rating']?.toString() ?? 'Unknown';
    if (field == 'Availability')
      return station['status']?.toString() ?? 'Unknown';
    return 'Vehicle profile required';
  }
}

class Profile extends StatefulWidget {
  const Profile({super.key});
  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final model = TextEditingController(),
      connector = TextEditingController(),
      capacity = TextEditingController(),
      battery = TextEditingController(),
      efficiency = TextEditingController(text: '5'),
      maxPower = TextEditingController();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile & vehicle')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Vehicle profile',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Saved vehicle context is used as a compatibility and battery-range constraint before recommendation scoring.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: model,
          decoration: const InputDecoration(labelText: 'EV model'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: connector,
          decoration: const InputDecoration(labelText: 'Compatible connector'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: capacity,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Battery capacity (kWh)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: battery,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Current battery (%)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: efficiency,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Efficiency (km/kWh)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: maxPower,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Vehicle maximum charging power (kW)',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            await context.read<StationStore>().saveVehicle({
              'model': model.text,
              'connector': connector.text,
              'capacity': double.tryParse(capacity.text),
              'battery': double.tryParse(battery.text),
              'efficiency': double.tryParse(efficiency.text),
              'maxPower': double.tryParse(maxPower.text),
            });
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vehicle profile saved')),
              );
          },
          child: const Text('Save vehicle profile'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FavouritesScreen()),
          ),
          icon: const Icon(Icons.favorite_outline),
          label: const Text('Saved favourites'),
        ),
        OutlinedButton(
          onPressed: () async {
            if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
            if (context.mounted)
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const Login()),
                (_) => false,
              );
          },
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
}

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});
  @override
  Widget build(BuildContext context) => Consumer<StationStore>(
    builder: (_, store, __) {
      final items = store.stations
          .where(
            (station) => store.favourites.contains(station['id'].toString()),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(title: const Text('Saved favourites')),
        body: items.isEmpty
            ? const Center(child: Text('No saved stations yet.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: items
                    .map((station) => StationCard(station: station))
                    .toList(),
              ),
      );
    },
  );
}

class ReviewSummary extends StatelessWidget {
  const ReviewSummary({required this.stationId, super.key});
  final String stationId;
  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: context.read<StationStore>().firestore.reviews(stationId),
    builder: (_, snapshot) {
      final docs = snapshot.data?.docs ?? const [];
      if (docs.isEmpty)
        return const ListTile(
          title: Text('Reviews'),
          subtitle: Text('No application reviews yet.'),
        );
      final ratings = docs
          .map((doc) => (doc.data()['rating'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      final average = ratings.isEmpty
          ? null
          : ratings.reduce((a, b) => a + b) / ratings.length;
      return ListTile(
        title: const Text('Reviews'),
        subtitle: Text(
          '${average?.toStringAsFixed(1) ?? 'Unknown'} / 5 from ${ratings.length} review(s)',
        ),
      );
    },
  );
}
