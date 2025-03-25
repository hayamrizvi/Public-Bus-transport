import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class JourneyHistoryScreen extends StatelessWidget {
  final String userId;

  JourneyHistoryScreen({required this.userId});

  @override
  Widget build(BuildContext context) {
    final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

    return Scaffold(
      appBar: AppBar(
        title: Text("Journey History"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              // Trigger a refresh of the data
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => JourneyHistoryScreen(userId: userId),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<DataSnapshot>(
        future: _databaseRef.child('users').child(userId).child('journeyHistory').get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingSkeleton();
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.value == null) {
            return Center(child: Text('No history found.'));
          } else {
            Map<dynamic, dynamic> historyMap = snapshot.data!.value as Map<dynamic, dynamic>;
            List<Map<dynamic, dynamic>> historyList = historyMap.entries.map((entry) {
              return {
                'key': entry.key,
                ...entry.value,
              };
            }).toList();

            return ListView.builder(
              padding: EdgeInsets.all(10),
              itemCount: historyList.length,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 3,
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(Icons.location_on, "From", historyList[index]['from'] ?? 'N/A'),
                        _buildDetailRow(Icons.flag, "To", historyList[index]['to'] ?? 'N/A'),
                        _buildDetailRow(Icons.calendar_today, "Date", historyList[index]['date'] ?? 'N/A'),
                        _buildDetailRow(Icons.access_time, "Time", historyList[index]['time'] ?? 'N/A'),
                        _buildDetailRow(Icons.attach_money, "Price", "\$${historyList[index]['price'] ?? 'N/A'}"),
                        _buildStatusRow(historyList[index]['status'] ?? 'N/A'),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
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

  Widget _buildStatusRow(String status) {
    Color statusColor = status.toLowerCase() == 'completed' ? Colors.green : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.circle, color: statusColor, size: 20),
          SizedBox(width: 10),
          Text(
            "Status: ",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: EdgeInsets.all(10),
      itemCount: 5, // Show 5 skeleton items
      itemBuilder: (context, index) {
        return Card(
          elevation: 3,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
              ],
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
}