import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key}); // Add `const` here

  @override
  _DashboardPageState createState() => _DashboardPageState();
}


class _DashboardPageState extends State<DashboardPage> {
  String userName = 'User';
  String latestChat = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    await Future.wait([
      _fetchUserName(),
      _fetchLatestChat(),
    ]);
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        setState(() {
          userName = doc.data()?['name'] ?? 'User';
        });
      } catch (e) {
        print('Error fetching user name: $e');
      }
    }
  }

  Future<void> _fetchLatestChat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('chats')
            .where('uid', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          setState(() {
            latestChat = snapshot.docs.first.data()['message']?.toString() ?? '';
          });
        }
      } catch (e) {
        print('Error fetching latest chat: $e');
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Healthpulse Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile section
            ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text("Welcome, $userName"),
            ),

            SizedBox(height: 20),

            // Menu section
            Expanded(
              flex: 2,
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  DashboardTile(
                    icon: Icons.chat,
                    label: 'AI Assistant',
                    onTap: () => Navigator.pushNamed(context, '/chat'),
                  ),
                  DashboardTile(
                    icon: Icons.bedtime,
                    label: 'Sleep Tracker',
                    onTap: () => Navigator.pushNamed(context, '/sleep'),
                  ),
                  // Add more tiles here if needed
                ],
              ),
            ),

            SizedBox(height: 20),

            // Chat preview section
            Expanded(
              flex: 1,
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.message, size: 30, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          latestChat.isNotEmpty
                              ? latestChat
                              : 'No recent chat yet.',
                          style: TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_forward),
                        onPressed: () => Navigator.pushNamed(context, '/chat'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const DashboardTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
