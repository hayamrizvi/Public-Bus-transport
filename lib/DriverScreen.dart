import 'dart:async';
import 'dart:math';
import 'package:bus_tracking/LoginScreen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ProfileScreen.dart';
import 'HelpScreen.dart';
import 'BookingDetailsScreen.dart';
import 'NotificationsScreen.dart';

class DriverScreen extends StatefulWidget {
  final String userId;

  DriverScreen({required this.userId});

  @override
  _DriverScreenState createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  bool _isSharingLocation = false;
  LatLng? _currentLocation;
  late StreamSubscription<Position> _positionStream;
  double _totalDistance = 0.0;
  Duration _trackingDurationToday = Duration.zero;
  DateTime? _trackingStartTime;
  Timer? _timer;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _startTimer();
    _fetchUserData();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  Future<void> _fetchUserData() async {
    DataSnapshot snapshot = await _databaseRef.child('users').child(widget.userId).get();
    if (snapshot.exists) {
      setState(() {
        _userData = Map<String, dynamic>.from(snapshot.value as Map);
        _totalDistance = _userData?['totalDistance'] ?? 0.0;
        _trackingDurationToday = Duration(seconds: _userData?['trackingDurationToday'] ?? 0);
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location services are disabled.")),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location permissions are denied.")),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location permissions are permanently denied.")),
      );
      return;
    }
  }

  void _startSharingLocation() {
    setState(() {
      _isSharingLocation = true;
      _trackingStartTime = DateTime.now();
    });

    _positionStream = Geolocator.getPositionStream().listen((position) {
      if (_currentLocation != null) {
        double distance = Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          position.latitude,
          position.longitude,
        );
        _totalDistance += distance;
      }

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      _updateLocationInRealtimeDatabase(position);
    });
  }

  void _stopSharingLocation() {
    setState(() {
      _isSharingLocation = false;
      _trackingDurationToday += DateTime.now().difference(_trackingStartTime!);
      _trackingStartTime = null;
    });

    _positionStream.cancel();
    _databaseRef.child('locations').child('driver_location').remove();
    _updateUserDataInDatabase();
  }

  void _updateLocationInRealtimeDatabase(Position position) {
    _databaseRef.child('locations').child('driver_location').set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _updateUserDataInDatabase() {
    _databaseRef.child('users').child(widget.userId).update({
      'totalDistance': _totalDistance,
      'trackingDurationToday': _trackingDurationToday.inSeconds,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void _showBookingDialog() {
    TextEditingController fromController = TextEditingController();
    TextEditingController toController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Create Booking"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fromController,
                  decoration: InputDecoration(labelText: "From"),
                ),
                TextField(
                  controller: toController,
                  decoration: InputDecoration(labelText: "To"),
                ),
                ListTile(
                  title: Text("Date: ${selectedDate.toLocal().toString().split(' ')[0]}"),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null && picked != selectedDate) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                ),
                ListTile(
                  title: Text("Time: ${selectedTime.format(context)}"),
                  trailing: Icon(Icons.access_time),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null && picked != selectedTime) {
                      setState(() {
                        selectedTime = picked;
                      });
                    }
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedDate = DateTime.now();
                      selectedTime = TimeOfDay.now();
                    });
                  },
                  child: Text("NOW"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (fromController.text.isNotEmpty && toController.text.isNotEmpty) {
                  double price = _calculateRandomPrice();
                  _createBooking(fromController.text, toController.text, selectedDate, selectedTime, price);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please fill all fields")),
                  );
                }
              },
              child: Text("Create Booking"),
            ),
          ],
        );
      },
    );
  }

  double _calculateRandomPrice() {
    return (100 + (Random().nextDouble() * 100)).roundToDouble();
  }

  void _createBooking(String from, String to, DateTime date, TimeOfDay time, double price) {
    String bookingId = _databaseRef.child('bookings').push().key!;
    _databaseRef.child('bookings').child(bookingId).set({
      'from': from,
      'to': to,
      'date': date.toIso8601String(),
      'time': "${time.hour}:${time.minute}",
      'price': price,
      'userId': widget.userId,
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Booking created successfully!")),
      );
      _showBookingDetailsPopup(from, to, date, time, price);
    });
  }

  void _showBookingDetailsPopup(String from, String to, DateTime date, TimeOfDay time, double price) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Booking Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("From: $from"),
              Text("To: $to"),
              Text("Date: ${date.toLocal().toString().split(' ')[0]}"),
              Text("Time: ${time.format(context)}"),
              Text("Price: \$${price.toStringAsFixed(2)}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _positionStream.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Driver Dashboard"),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => NotificationsScreen(userId: widget.userId)),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blueAccent,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                if (_userData != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                          userId: widget.userId, userData: _userData),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Please wait, loading profile data...")),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.help),
              title: Text('Help'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HelpScreen(userId: widget.userId)),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.book),
              title: Text('Booking Details'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingDetailsScreen(userId: widget.userId),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildLocationCard(),
              SizedBox(height: 20),
              _buildActionButtons(),
              SizedBox(height: 20),
              _buildDashboardCards(),
              ElevatedButton(
                onPressed: _showBookingDialog,
                child: Text("Create Booking"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Current Location",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            _currentLocation != null
                ? "Lat: ${_currentLocation!.latitude}, Lng: ${_currentLocation!.longitude}"
                : "Location not available",
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: _isSharingLocation ? null : _startSharingLocation,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          child: Text("Start Location"),
        ),
        ElevatedButton(
          onPressed: _isSharingLocation ? _stopSharingLocation : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          child: Text("End Location"),
        ),
      ],
    );
  }

  Widget _buildDashboardCards() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 1,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildDashboardCard(
          "Total Distance",
          "${(_totalDistance / 1000).toStringAsFixed(2)} KM",
          Icons.directions_walk,
        ),
        _buildDashboardCard(
          "Tracking Today",
          _isSharingLocation ? "ON" : "OFF",
          Icons.timer,
          subtitle: _trackingStartTime != null
              ? "Time: ${_getFormattedTime(DateTime.now())}\nDuration: ${_getFormattedDuration(_trackingDurationToday + DateTime.now().difference(_trackingStartTime!))}"
              : "Time: ${_getFormattedTime(DateTime.now())}\nDuration: ${_getFormattedDuration(_trackingDurationToday)}",
        ),
      ],
    );
  }

  Widget _buildDashboardCard(String title, String value, IconData icon,
      {String? subtitle}) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.blueAccent),
          SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getFormattedTime(DateTime time) {
    return "${time.hour}:${time.minute}:${time.second}";
  }

  String _getFormattedDuration(Duration duration) {
    return "${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s";
  }
}

