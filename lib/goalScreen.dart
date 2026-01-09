import 'package:flutter/material.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  int _currentIndex = 0;

  final List<Map<String, dynamic>> sampleGoals = [
    {
      'title': 'Drink Water',
      'subtitle': 'Upload daily proof',
      'image': null,
    },
    {
      'title': 'Walk 5000 Steps',
      'subtitle': 'Upload daily proof',
      'image': null,
    },
    {
      'title': 'Read 20 Pages',
      'subtitle': 'Upload daily proof',
      'image': null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      _buildDiscoverTab(),
      _buildJoinedTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('HabitBuddy'),
        backgroundColor: Colors.yellow[700],
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 24,
              backgroundImage: AssetImage('assets/user.jpg'),
            ),
            onPressed: () {
                // Navigate to profile screen
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Joined',
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sampleGoals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final goal = sampleGoals[index];
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal['title'],
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(goal['subtitle']),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // Upload image proof logic
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Upload Proof'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Open chat for this goal
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJoinedTab() {
    // For simplicity, just reuse the same cards
    return _buildDiscoverTab();
  }
}
