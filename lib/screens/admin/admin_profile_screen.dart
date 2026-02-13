import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mygame/screens/login_screen.dart';
import 'package:mygame/services/firebase_service.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  // Unchanged helper methods
  void _showChangeCodeDialog(BuildContext context, String currentCode) {
    final codeController = TextEditingController(text: currentCode);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Registration Code'),
        content: TextField(controller: codeController, decoration: const InputDecoration(labelText: 'New Code')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.isNotEmpty) {
                await FirebaseService().updateRegistrationCode(codeController.text);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (value) => (value?.length ?? 0) < 6 ? 'Password must be at least 6 characters' : null,
              ),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
                validator: (value) => value != passwordController.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await FirebaseAuth.instance.currentUser?.updatePassword(passwordController.text);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green));
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getProfitTransactionsStream(String adminId) {
    return FirebaseFirestore.instance
        .collection('players')
        .doc(adminId)
        .collection('transactions')
        .where('type', isEqualTo: 'game_profit')
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not logged in'));

    const primaryTextColor = Colors.white;
    const secondaryTextColor = Colors.white70;
    const accentColor = Colors.yellow;
    const profitColor = Colors.greenAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A), // Dark blue-black background
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Admin Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryTextColor)),
          const SizedBox(height: 24),
          Card(
            color: const Color(0xFF1C1C3A), // Darker card color
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email, color: secondaryTextColor),
                  title: const Text('Admin Email', style: TextStyle(color: primaryTextColor)),
                  subtitle: Text(user.email ?? 'N/A', style: const TextStyle(color: secondaryTextColor)),
                ),
                const Divider(color: Colors.white24),
                StreamBuilder<String>(
                  stream: FirebaseService().getRegistrationCodeStream(),
                  builder: (context, snapshot) {
                    final code = snapshot.data ?? 'Loading...';
                    return ListTile(
                      leading: const Icon(Icons.vpn_key, color: secondaryTextColor),
                      title: const Text('Registration Code', style: TextStyle(color: primaryTextColor)),
                      subtitle: Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accentColor)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () => _showChangeCodeDialog(context, code),
                        tooltip: 'Change Code',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showChangePasswordDialog(context),
            icon: const Icon(Icons.lock, color: Colors.black87),
            label: const Text('Change Password'),
            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.black87),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Log Out'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
          ),
          const Divider(height: 40, color: Colors.white24),
          const Text('Profit Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryTextColor)),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _getProfitTransactionsStream(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No game profits recorded yet.', style: TextStyle(color: secondaryTextColor)));
              }

              final transactions = snapshot.data!.docs;
              double todaysProfit = 0;
              final now = DateTime.now();
              final startOfToday = DateTime(now.year, now.month, now.day);

              for (var doc in transactions) {
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['date'] as Timestamp?)?.toDate();
                if (date != null && date.isAfter(startOfToday)) {
                  todaysProfit += (data['amount'] as num?)?.toDouble() ?? 0.0;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: accentColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(side: BorderSide(color: accentColor), borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Today\'s Profit: ${todaysProfit.toStringAsFixed(2)} ETB',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Recent Profits:', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final doc = transactions[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                      final reason = data['reason'] as String? ?? 'N/A';
                      final date = (data['date'] as Timestamp?)?.toDate();
                      final formattedDate = date != null ? DateFormat.yMd().add_jm().format(date) : 'N/A';

                      return ListTile(
                        leading: const Icon(Icons.trending_up, color: profitColor),
                        title: Text(reason, style: const TextStyle(color: primaryTextColor)),
                        subtitle: Text(formattedDate, style: const TextStyle(color: secondaryTextColor)),
                        trailing: Text('+${amount.toStringAsFixed(2)} ETB', style: const TextStyle(fontWeight: FontWeight.bold, color: profitColor)),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
