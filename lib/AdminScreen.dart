import 'dart:async';
import 'dart:math';
import 'package:bus_tracking/LoginScreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'booking_history_screen.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<Map<dynamic, dynamic>> _helpRequests = [];
  final TextEditingController _replyController = TextEditingController();
  late MapController _mapController;
  LatLng? _driverLocation;
  double _totalDistance = 0.0;
  Duration _trackingDuration = Duration.zero;
  String _driverName = "Loading...";
  String _driverBusRegNum = "Loading...";
  String _driverContactNum = "Loading...";
  String _driverEmail = "Loading...";
  String _driverUid = "";
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _fetchDriverLocation();
    _fetchDriverDetails();
    _fetchHelpRequests();
  }

  Future<void> _fetchHelpRequests() async {
    DataSnapshot snapshot = await _databaseRef.child('helpRequests').get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> helpRequestsMap =
          snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _helpRequests = helpRequestsMap.entries.map((entry) {
          return {
            'key': entry.key,
            ...entry.value,
          };
        }).toList();
      });
    }
  }

  Future<void> _sendReply(String userId, String helpRequestId) async {
    if (_replyController.text.isNotEmpty) {
      await _databaseRef.child('notifications').child(userId).push().set({
        'message': _replyController.text,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _replyController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reply sent successfully!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reply cannot be empty!")),
      );
    }
  }

  void _fetchDriverLocation() {
    _databaseRef
        .child('locations')
        .child('driver_location')
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _driverLocation = LatLng(
            data['latitude'] as double,
            data['longitude'] as double,
          );
        });
        _mapController.move(_driverLocation!, 15.0);
      }
    });
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void _fetchDriverDetails() {
    _databaseRef
        .child('users')
        .orderByChild('role')
        .equalTo('user')
        .limitToFirst(1)
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final driverData = data.values.first;
        setState(() {
          _driverUid = driverData['uid'];
          _driverName = driverData['name'] ?? "Unknown Driver";
          _driverBusRegNum = driverData['busReg'] ?? "Unknown Driver";
          _driverContactNum = driverData['phone'] ?? "Unknown Driver";
          _driverEmail = driverData['email'];
          _totalDistance = driverData['totalDistance'] ?? 0.0;
          _trackingDuration =
              Duration(seconds: driverData['trackingDurationToday'] ?? 0);
        });
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showBookingDialog(String driverId) {
    TextEditingController fromController = TextEditingController();
    TextEditingController toController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isDriverBusy = false; // Track if the driver is busy
    bool isJourneyOngoing = false; // Track if the journey is ongoing

    // Fetch the driver's current journey status
    _databaseRef.child('users').child(driverId).get().then((snapshot) {
      if (snapshot.exists) {
        Map<dynamic, dynamic> driverData =
            snapshot.value as Map<dynamic, dynamic>;
        if (driverData['currentJourney'] != null) {
          isDriverBusy = true;
          if (driverData['currentJourney']['status'] == 'ongoing') {
            isJourneyOngoing = true;
          }
        }
      }
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Center(
                child: Text(
                  "Create Booking",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDriverBusy)
                      Column(
                        children: [
                          Text(
                            "Driver is busy right now.",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isJourneyOngoing)
                            Text(
                              "Check the driver's location on the dashboard.",
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          SizedBox(height: 10),
                        ],
                      ),
                    TextField(
                      controller: fromController,
                      decoration: InputDecoration(
                        labelText: "From",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: toController,
                      decoration: InputDecoration(
                        labelText: "To",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    SizedBox(height: 15),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      tileColor: Colors.grey[200],
                      title: Text(
                        "Date: ${selectedDate.toLocal().toString().split(' ')[0]}",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing:
                          Icon(Icons.calendar_today, color: Colors.blueAccent),
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
                    SizedBox(height: 10),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      tileColor: Colors.grey[200],
                      title: Text(
                        "Time: ${selectedTime.format(context)}",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing:
                          Icon(Icons.access_time, color: Colors.blueAccent),
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
                    SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedDate = DateTime.now();
                          selectedTime = TimeOfDay.now();
                        });
                      },
                      icon: Icon(Icons.timer, color: Colors.green),
                      label: Text("Set to NOW"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: isDriverBusy
                          ? null // Disable the button if the driver is busy
                          : () {
                              if (fromController.text.isNotEmpty &&
                                  toController.text.isNotEmpty) {
                                double price = _calculateRandomPrice();
                                _createBooking(
                                  fromController.text,
                                  toController.text,
                                  selectedDate,
                                  selectedTime,
                                  price,
                                  driverId,
                                );
                                Navigator.pop(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text("Please fill all fields")),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDriverBusy ? Colors.grey : Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text("Create Booking"),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  double _calculateRandomPrice() {
    return (100 + (Random().nextDouble() * 100)).roundToDouble();
  }

  void _createBooking(
    String from,
    String to,
    DateTime date,
    TimeOfDay time,
    double price,
    String driverId, // Added driverId parameter
  ) {
    // Generate a unique booking ID
    String bookingId = _databaseRef.child('bookings').push().key!;

    // Combine date and time into a single DateTime object
    DateTime bookingDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // Save the booking to Firebase
    _databaseRef.child('bookings').child(bookingId).set({
      'from': from,
      'to': to,
      'date': bookingDateTime.toIso8601String(), // Use combined DateTime
      'time': "${time.hour}:${time.minute}", // Optional: Keep time as string
      'price': price,
      'userId':
          _driverUid, // Assuming _driverUid is the user creating the booking
      'driverId': driverId, // Associate the booking with the driver
      'status': 'pending', // Initial status
    }).then((_) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Booking created successfully!")),
      );

      // Show booking details popup
      _showBookingDetailsPopup(from, to, date, time, price);
    }).catchError((error) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create booking: $error")),
      );
    });
  }

  void _showBookingDetailsPopup(
      String from, String to, DateTime date, TimeOfDay time, double price) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Center(
            child: Text(
              "Booking Details",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailTile(Icons.location_on, "From", from),
              _buildDetailTile(Icons.flag, "To", to),
              _buildDetailTile(Icons.calendar_today, "Date",
                  date.toLocal().toString().split(' ')[0]),
              _buildDetailTile(Icons.access_time, "Time", time.format(context)),
              _buildDetailTile(
                  Icons.attach_money, "Price", "\$${price.toStringAsFixed(2)}"),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text("OK"),
              ),
            ),
          ],
        );
      },
    );
  }

// Helper function for cleaner UI
  Widget _buildDetailTile(IconData icon, String title, String value) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          value,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Dashboard"),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: _selectedIndex == 0
          ? Column(
              children: [
                Expanded(
                  flex: 1,
                  child: ListView.builder(
                    itemCount: _helpRequests.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(_helpRequests[index]['message']),
                        subtitle: Text(_helpRequests[index]['timestamp']),
                        trailing: IconButton(
                          icon: Icon(Icons.reply),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text("Reply to Help Request"),
                                  content: TextField(
                                    controller: _replyController,
                                    decoration:
                                        InputDecoration(labelText: "Reply"),
                                    maxLines: 5,
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
                                        _sendReply(
                                          _helpRequests[index]['userId'],
                                          _helpRequests[index]['key'],
                                        );
                                        Navigator.pop(context);
                                      },
                                      child: Text("Send"),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: _driverLocation ?? LatLng(0.0, 0.0),
                      zoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: _driverLocation != null
                            ? [
                                Marker(
                                  point: _driverLocation!,
                                  child: Icon(Icons.location_pin,
                                      color: Colors.blue, size: 40),
                                ),
                              ]
                            : [],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          "Driver Details",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        SizedBox(height: 10),
                        _buildDriverDetailCard(
                          "Driver Name",
                          _driverName,
                          Icons.person,
                        ),
                        SizedBox(height: 10),
                        _buildDriverDetailCard(
                          "Driver Email",
                          _driverEmail,
                          Icons.email,
                        ),
                        SizedBox(height: 10),
                        _buildDriverDetailCard(
                          "Total Distance",
                          "${(_totalDistance / 1000).toStringAsFixed(2)} KM",
                          Icons.directions_car,
                        ),
                        SizedBox(height: 10),
                        _buildDriverDetailCard(
                          "Tracking Duration",
                          "${_trackingDuration.inHours}h ${_trackingDuration.inMinutes.remainder(60)}m ${_trackingDuration.inSeconds.remainder(60)}s",
                          Icons.timer,
                        ),
                        SizedBox(height: 10),
                        _buildDriverDetailCard(
                          "Driver Contact Number",
                          _driverContactNum,
                          Icons.person,
                        ),
                        SizedBox(height: 10),
                        _buildDriverDetailCard(
                          "Bus Reg Number",
                          _driverBusRegNum,
                          Icons.person,
                        ),
                        SizedBox(height: 10),
                        ListTile(
                          leading: Icon(Icons.logout),
                          title: Text('Logout'),
                          onTap: _logout,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : _buildBookingPage(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Booking',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildBookingPage() {
    return Column(
      children: [
        SizedBox(height: 20), // Spacing from the top
        Text(
          'Available Drivers',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10), // Spacing below the title
        Expanded(
          child: FutureBuilder<DataSnapshot>(
            future: _databaseRef
                .child('users')
                .orderByChild('role')
                .equalTo('user')
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.value == null) {
                return Center(child: Text('No users found.'));
              } else {
                Map<dynamic, dynamic> usersMap =
                    snapshot.data!.value as Map<dynamic, dynamic>;
                List<Map<dynamic, dynamic>> usersList =
                    usersMap.entries.map((entry) {
                  return {
                    'key': entry.key,
                    ...entry.value,
                  };
                }).toList();

                return ListView.builder(
                  padding: EdgeInsets.all(10),
                  itemCount: usersList.length,
                  itemBuilder: (context, index) {
                    // Fetch the driver's current journey status
                    String driverId = usersList[index]['key'];
                    bool isDriverBusy =
                        usersList[index]['currentJourney'] != null;

                    return Card(
                      elevation: 3,
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          usersList[index]['name'],
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(usersList[index]['email']),
                            if (isDriverBusy)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Driver is busy right now.",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Check the driver's location on the dashboard.",
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: isDriverBusy
                              ? null // Disable the button if the driver is busy
                              : () => _showBookingDialog(driverId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDriverBusy ? Colors.grey : Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('Book'),
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
       
        SizedBox(height: 10), // Spacing below the title
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingHistoryScreen(userId: _driverUid),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text("View Booking History"),
        ),
      ],
    );
  }

  Widget _buildDriverDetailCard(String title, String value, IconData icon) {
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
      child: Row(
        children: [
          Icon(icon, size: 30, color: Colors.blueAccent),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
