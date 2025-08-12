import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

const LatLng lojaDefault = LatLng(-3.99313, -79.20422); // Coordinates de Loja

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Maps App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Marker? _userMarker;
  LatLng _cameraPosition = lojaDefault; // inicia en Loja si no hay ubicación
  StreamSubscription<Position>? _positionStreamSub;
  bool _tracking = false;
  String _statusMessage = 'Inicializando...';

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocationTracking() async {
    setState(() => _statusMessage = 'Verificando servicios y permisos...');
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _statusMessage = 'Servicio de ubicación desactivado.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _statusMessage = 'Permiso de ubicación denegado.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _statusMessage = 'Permiso denegado permanentemente. Habilitar en ajustes.');
      return;
    }

    setState(() => _statusMessage = 'Obteniendo ubicación actual...');
    try {
      // Obtener la ubicación actual una vez para centrar el mapa
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _updateLocationOnMap(LatLng(pos.latitude, pos.longitude), moveCamera: true);
      setState(() => _statusMessage = 'Ubicación obtenida. Rastreo activo.');
    } catch (e) {
      // Si falla, usamos Loja por defecto
      setState(() => _statusMessage = 'No se pudo obtener ubicación inicial. Usando Loja por defecto.');
      _updateLocationOnMap(lojaDefault, moveCamera: true, title: 'Loja (por defecto)');
    }

    // Iniciar stream de posición (actualización en tiempo real)
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Optimización: cambiar distanceFilter para menos actualizaciones (metros)
        distanceFilter: 15,
      ),
    ).listen((Position position) {
      _updateLocationOnMap(LatLng(position.latitude, position.longitude), moveCamera: true);
    });

    setState(() {
      _tracking = true;
    });
  }

  void _updateLocationOnMap(LatLng pos, {bool moveCamera = false, String? title}) {
    final marker = Marker(
      markerId: const MarkerId('user_marker'),
      position: pos,
      infoWindow: InfoWindow(title: title ?? 'Tu ubicación'),
    );
    setState(() {
      _userMarker = marker;
      _cameraPosition = pos;
    });
    if (moveCamera && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(pos));
    }
  }

  void _toggleTracking() {
    if (_tracking) {
      _positionStreamSub?.pause();
      setState(() {
        _tracking = false;
        _statusMessage = 'Rastreo en pausa.';
      });
    } else {
      _positionStreamSub?.resume();
      setState(() {
        _tracking = true;
        _statusMessage = 'Rastreo activo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geolocalización — Google Maps'),
        actions: [
          IconButton(
            icon: Icon(_tracking ? Icons.pause_circle : Icons.play_circle),
            tooltip: _tracking ? 'Pausar rastreo' : 'Reanudar rastreo',
            onPressed: _toggleTracking,
          )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _cameraPosition, zoom: 15),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _userMarker != null ? {_userMarker!} : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 18,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_statusMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lat: ${_cameraPosition.latitude.toStringAsFixed(6)}'),
                        Text('Lng: ${_cameraPosition.longitude.toStringAsFixed(6)}')
                      ],
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
