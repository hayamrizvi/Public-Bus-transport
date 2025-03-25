import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class BookingHistoryScreen extends StatelessWidget {
  final String userId;

  BookingHistoryScreen({required this.userId});

  @override
  Widget build(BuildContext context) {
    final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

    return Scaffold(
      appBar: AppBar(
        title: Text("Booking History"),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: FutureBuilder<DataSnapshot>(
        future: _databaseRef.child('bookings').orderByChild('userId').equalTo(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.value == null) {
            return Center(child: Text('No booking history found.'));
          } else {
            Map<dynamic, dynamic> bookingsMap = snapshot.data!.value as Map<dynamic, dynamic>;
            List<Map<dynamic, dynamic>> bookingsList = bookingsMap.entries.map((entry) {
              return {
                'key': entry.key,
                ...entry.value,
              };
            }).toList();

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: bookingsList.length,
              itemBuilder: (context, index) {
                return _buildBookingCard(bookingsList[index]);
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<dynamic, dynamic> booking) {
    DateTime date = DateTime.parse(booking['date']);
    String time = booking['time'];
    String status = booking['status'] ?? 'pending';

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent.withOpacity(0.1), Colors.purpleAccent.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "From: ${booking['from']}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "To: ${booking['to']}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Date: ${date.toLocal().toString().split(' ')[0]}",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 8),
              Text(
                "Time: $time",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 8),
              Text(
                "Price: \$${booking['price']}",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 8),
              _buildStatusChip(status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    switch (status) {
      case 'ongoing':
        chipColor = Colors.orange;
        break;
      case 'completed':
        chipColor = Colors.green;
        break;
      case 'canceled':
        chipColor = Colors.red;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: chipColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}