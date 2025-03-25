import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'JourneyHistoryScreen.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String userId;

  BookingDetailsScreen({required this.userId});

  @override
  _BookingDetailsScreenState createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  String? _currentJourneyId;
  bool _isJourneyInProgress = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentJourney();
  }

  Future<void> _fetchCurrentJourney() async {
    DataSnapshot snapshot = await _databaseRef.child('users').child(widget.userId).child('currentJourney').get();
    if (snapshot.exists) {
      setState(() {
        _currentJourneyId = snapshot.value as String?;
        _isJourneyInProgress = _currentJourneyId != null;
      });
    }
  }

  void _startJourney(String bookingId) {
    setState(() {
      _currentJourneyId = bookingId;
      _isJourneyInProgress = true;
    });

    _databaseRef.child('bookings').child(bookingId).update({
      'status': 'ongoing',
    });

    _databaseRef.child('users').child(widget.userId).update({
      'currentJourney': bookingId,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Journey started!")),
    );
  }

  void _endJourney(String bookingId) async {
    DataSnapshot bookingSnapshot = await _databaseRef.child('bookings').child(bookingId).get();
    if (bookingSnapshot.exists) {
      Map<dynamic, dynamic> bookingData = bookingSnapshot.value as Map<dynamic, dynamic>;

      _databaseRef.child('users').child(widget.userId).child('journeyHistory').push().set({
        ...bookingData,
        'endedAt': DateTime.now().toIso8601String(),
        'status': 'completed',
      });

      _databaseRef.child('users').child(widget.userId).update({
        'currentJourney': null,
      });

      _databaseRef.child('bookings').child(bookingId).update({
        'status': 'completed',
      });

      setState(() {
        _currentJourneyId = null;
        _isJourneyInProgress = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Journey completed and added to history!")),
      );
    }
  }

  void _cancelJourney(String bookingId) async {
    DataSnapshot bookingSnapshot = await _databaseRef.child('bookings').child(bookingId).get();
    if (bookingSnapshot.exists) {
      Map<dynamic, dynamic> bookingData = bookingSnapshot.value as Map<dynamic, dynamic>;

      _databaseRef.child('users').child(widget.userId).child('journeyHistory').push().set({
        ...bookingData,
        'endedAt': DateTime.now().toIso8601String(),
        'status': 'canceled',
      });

      _databaseRef.child('users').child(widget.userId).update({
        'currentJourney': null,
      });

      _databaseRef.child('bookings').child(bookingId).update({
        'status': 'canceled',
      });

      setState(() {
        _currentJourneyId = null;
        _isJourneyInProgress = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Journey canceled and added to history!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Booking Details"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JourneyHistoryScreen(userId: widget.userId),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<DataSnapshot>(
        future: _databaseRef.child('bookings').orderByChild('userId').equalTo(widget.userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingSkeleton();
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.value == null) {
            return Center(child: Text('No bookings found.'));
          } else {
            Map<dynamic, dynamic> bookingsMap = snapshot.data!.value as Map<dynamic, dynamic>;
            List<Map<dynamic, dynamic>> bookingsList = bookingsMap.entries.map((entry) {
              return {
                'key': entry.key,
                ...entry.value,
              };
            }).toList();

            // Filter out completed and canceled journeys
            bookingsList = bookingsList.where((booking) => booking['status'] != 'completed' && booking['status'] != 'canceled').toList();

            return ListView.builder(
              padding: EdgeInsets.all(10),
              itemCount: bookingsList.length,
              itemBuilder: (context, index) {
                bool isCurrentJourney = _currentJourneyId == bookingsList[index]['key'];
                return _buildBookingCard(bookingsList[index], isCurrentJourney);
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<dynamic, dynamic> booking, bool isCurrentJourney) {
    return Card(
      elevation: 5,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.location_on, "From", booking['from'] ?? 'N/A'),
              _buildDetailRow(Icons.flag, "To", booking['to'] ?? 'N/A'),
              _buildDetailRow(Icons.calendar_today, "Date", booking['date'] ?? 'N/A'),
              _buildDetailRow(Icons.access_time, "Time", booking['time'] ?? 'N/A'),
              _buildDetailRow(Icons.attach_money, "Price", "\$${booking['price'] ?? 'N/A'}"),
              _buildStatusChip(booking['status'] ?? 'N/A'),
              SizedBox(height: 10),
              _buildJourneyControls(booking['key'], isCurrentJourney),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          SizedBox(width: 10),
          Text(
            "$title: ",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor = status == 'ongoing' ? Colors.orange : Colors.green;
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: chipColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildJourneyControls(String bookingId, bool isCurrentJourney) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.play_arrow,
          label: "Start",
          color: Colors.blueAccent,
          onPressed: _isJourneyInProgress ? null : () => _startJourney(bookingId),
        ),
        _buildActionButton(
          icon: Icons.stop,
          label: "End",
          color: Colors.redAccent,
          onPressed: isCurrentJourney ? () => _endJourney(bookingId) : null,
        ),
        _buildActionButton(
          icon: Icons.cancel,
          label: "Cancel",
          color: Colors.orangeAccent,
          onPressed: _isJourneyInProgress ? null : () => _cancelJourney(bookingId),
        ),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, VoidCallback? onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: EdgeInsets.all(10),
      itemCount: 5, // Show 5 skeleton items
      itemBuilder: (context, index) {
        return Card(
          elevation: 5,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSkeletonRow(),
                  _buildSkeletonRow(),
                  _buildSkeletonRow(),
                  _buildSkeletonRow(),
                  _buildSkeletonRow(),
                  SizedBox(height: 10),
                  _buildSkeletonButtonRow(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonButtonRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
          width: 80,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Container(
          width: 80,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Container(
          width: 80,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
}