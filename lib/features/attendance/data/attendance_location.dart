import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'attendance_api.dart';

final attendanceLocationProvider = Provider<Future<AttendanceFix> Function()>(
  (ref) => readAttendanceLocation,
);

enum LocationIssue implements Exception {
  disabled('Activa la ubicación del teléfono para marcar asistencia.'),
  denied('Permite el acceso a la ubicación mientras usas la app.'),
  settings('Activa el permiso de ubicación de TRAIGO en los ajustes.'),
  timeout('No se pudo obtener la ubicación a tiempo. Intenta de nuevo.'),
  simulated('La ubicación simulada no se puede usar para marcar asistencia.');

  const LocationIssue(this.message);
  final String message;
}

Future<AttendanceFix> readAttendanceLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw LocationIssue.disabled;
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw LocationIssue.settings;
  }
  if (permission != LocationPermission.whileInUse &&
      permission != LocationPermission.always) {
    throw LocationIssue.denied;
  }

  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    if (position.isMocked) throw LocationIssue.simulated;
    return AttendanceFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      capturedAt: position.timestamp,
    );
  } on LocationServiceDisabledException {
    throw LocationIssue.disabled;
  } on TimeoutException {
    throw LocationIssue.timeout;
  }
}
