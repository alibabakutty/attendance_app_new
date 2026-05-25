import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationTracker extends StatefulWidget {
  const LocationTracker(
      {super.key, this.mobileNumber, required this.attendanceDate});

  final String? mobileNumber;
  final String attendanceDate;

  @override
  State<LocationTracker> createState() => _LocationTrackerState();
}

class _LocationTrackerState extends State<LocationTracker> {
  Map<String, dynamic>? attendanceData;
  final baseUrl = dotenv.env['API_BASE_URL'];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchAttendance();
  }

  Future<void> fetchAttendance() async {
    try {
      final url = Uri.parse(
        '$baseUrl/api/v1/attendance-masters/search-by-mobile-number-and-date'
        '?mobileNumber=${widget.mobileNumber}'
        '&attendanceDate=${widget.attendanceDate}',
      );

      print(url);

      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          attendanceData = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          error = "Failed to load attendance";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Widget infoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget mapCard({
    required String title,
    required double latitude,
    required double longitude,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      latitude,
                      longitude,
                    ),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.attendance_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            latitude,
                            longitude,
                          ),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lat: $latitude, Lng: $longitude',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Text(error!),
        ),
      );
    }

    final data = attendanceData!;

    final officeInLat = data['officeTimeInLocation']['latitude'];

    final officeInLng = data['officeTimeInLocation']['longitude'];

    final officeOutLat = data['officeTimeOutLocation']['latitude'];

    final officeOutLng = data['officeTimeOutLocation']['longitude'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Details"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            sectionCard(
              title: "Employee Info",
              children: [
                infoTile(
                  "Employee ID",
                  data['employeeId'],
                ),
                infoTile(
                  "Name",
                  data['employeeName'],
                ),
                infoTile(
                  "Mobile",
                  data['mobileNumber'],
                ),
                infoTile(
                  "Site",
                  data['siteName'],
                ),
                infoTile(
                  "Date",
                  data['attendanceDate'],
                ),
              ],
            ),
            const SizedBox(height: 16),
            sectionCard(
              title: "Office Attendance",
              children: [
                infoTile(
                  "Office In",
                  data['officeTimeIn'],
                ),
                infoTile(
                  "Office Out",
                  data['officeTimeOut'],
                ),
                infoTile(
                  "Status",
                  data['status'],
                ),
              ],
            ),
            const SizedBox(height: 16),
            sectionCard(
              title: "Permission Details",
              children: [
                infoTile(
                  "Permission In",
                  data['permissionTimeIn'],
                ),
                infoTile(
                  "Permission Out",
                  data['permissionTimeOut'],
                ),
                infoTile(
                  "Total Hours",
                  data['totalPermissionHours'],
                ),
              ],
            ),
            const SizedBox(height: 16),
            mapCard(
              title: "Office Check-In Location",
              latitude: officeInLat,
              longitude: officeInLng,
            ),
            const SizedBox(height: 16),
            mapCard(
              title: "Office Check-Out Location",
              latitude: officeOutLat,
              longitude: officeOutLng,
            ),
          ],
        ),
      ),
    );
  }
}
