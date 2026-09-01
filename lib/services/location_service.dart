import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_models.dart';

class AddressSearchResult {
  const AddressSearchResult({required this.label, required this.point});
  final String label;
  final LatLng point;
}

class LocationService {
  static const _headers = {
    'User-Agent': 'GoBran/1.0 (admin@gobran.id)',
    'Accept-Language': 'id',
  };

  Future<LatLng> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception(
        'GPS belum aktif. Aktifkan lokasi perangkat terlebih dahulu.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak. Aktifkan izin lokasi dari pengaturan aplikasi.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LatLng(position.latitude, position.longitude);
  }

  Stream<LatLng> locationStream() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    ),
  ).map((position) => LatLng(position.latitude, position.longitude));

  Future<List<AddressSearchResult>> searchAddress(String query) async {
    if (query.trim().length < 3) return [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': '$query, Babalan, Langkat, Sumatera Utara',
      'format': 'jsonv2',
      'limit': '6',
      'countrycodes': 'id',
      'addressdetails': '1',
    });
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Pencarian alamat sedang tidak tersedia.');
    }
    final list = jsonDecode(response.body) as List;
    return list.map((raw) {
      final data = Map<String, dynamic>.from(raw as Map);
      return AddressSearchResult(
        label: data['display_name'] ?? '',
        point: LatLng(double.parse(data['lat']), double.parse(data['lon'])),
      );
    }).toList();
  }

  Future<String> reverseGeocode(LatLng point) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'format': 'jsonv2',
      'zoom': '18',
    });
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      return '${point.latitude}, ${point.longitude}';
    }
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return data['display_name'] ?? '${point.latitude}, ${point.longitude}';
  }

  Future<MapRoute> route(LatLng start, LatLng destination) async {
    final coordinates =
        '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=geojson&steps=false',
    );
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Rute jalan tidak dapat dihitung.');
    }
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final routes = data['routes'] as List? ?? [];
    if (routes.isEmpty) {
      throw Exception('Tidak ditemukan rute antara kedua lokasi.');
    }
    final first = Map<String, dynamic>.from(routes.first as Map);
    final geometry = Map<String, dynamic>.from(first['geometry'] as Map);
    final coordinatesList = geometry['coordinates'] as List? ?? [];
    return MapRoute(
      points: coordinatesList.map((raw) {
        final pair = raw as List;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList(),
      distanceKm: ((first['distance'] as num?)?.toDouble() ?? 0) / 1000,
      durationMinutes: ((first['duration'] as num?)?.toDouble() ?? 0) / 60,
    );
  }

  Future<void> openGoogleMaps(
    AddressPoint destination, {
    AddressPoint? origin,
    List<AddressPoint> waypoints = const [],
  }) async {
    final params = <String, String>{
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'two-wheeler',
      'dir_action': 'navigate',
    };
    if (origin != null) {
      params['origin'] = '${origin.latitude},${origin.longitude}';
    }
    if (waypoints.isNotEmpty) {
      params['waypoints'] = waypoints
          .map((point) => '${point.latitude},${point.longitude}')
          .join('|');
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', params);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Google Maps tidak dapat dibuka.');
    }
  }

  Future<String> resolveRedirect(String url) async {
    var currentUrl = url;
    final client = http.Client();
    try {
      for (int i = 0; i < 5; i++) {
        if (!currentUrl.startsWith('http')) break;
        final uri = Uri.tryParse(currentUrl);
        if (uri == null) break;
        final request = http.Request('GET', uri)..followRedirects = false;
        final response = await client.send(request);
        final location = response.headers['location'];
        if (location == null) break;
        if (location.startsWith('/')) {
          currentUrl = uri.replace(path: location).toString();
        } else {
          currentUrl = location;
        }
      }
    } catch (_) {
      // Fallback to original url on network issues
    } finally {
      client.close();
    }
    return currentUrl;
  }
}
