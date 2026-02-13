import 'package:flutter/material.dart';
import 'package:mygame/config/game_config.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('Game Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1C1C3A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Profit Sharing Configuration'),
            _buildProfitSharingCard(),
            const SizedBox(height: 24),
            _buildSectionTitle('Game Settings'),
            _buildGameSettingsCard(),
            const SizedBox(height: 24),
            _buildSectionTitle('System Configuration'),
            _buildSystemSettingsCard(),
            const SizedBox(height: 24),
            _buildProfitCalculator(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildProfitSharingCard() {
    return Card(
      color: const Color(0xFF1C1C3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, color: Colors.amber, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Revenue Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildShareRow(
              'Winners Share',
              GameConfig.winnerShareDisplay,
              Colors.greenAccent,
              Icons.emoji_events,
              'Distributed among all winners',
            ),
            const SizedBox(height: 12),
            _buildShareRow(
              'Admin Share',
              GameConfig.adminShareDisplay,
              Colors.blueAccent,
              Icons.business_center,
              'Platform profit for admin',
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Formula:',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total Pool = Cards Sold × Card Cost\n'
                    'Winners = Total Pool × ${GameConfig.winnerShareNumerator}/${GameConfig.totalShareDenominator}\n'
                    'Admin = Total Pool × ${GameConfig.adminShareNumerator}/${GameConfig.totalShareDenominator}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareRow(String title, String percentage, Color color, IconData icon, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            percentage,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameSettingsCard() {
    return Card(
      color: const Color(0xFF1C1C3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Game Parameters',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingRow('Max Retries', '${GameConfig.maxRetries} attempts'),
            _buildSettingRow('Transaction Timeout', '${GameConfig.transactionTimeoutSeconds} seconds'),
            _buildSettingRow('Max Cards Per Player', '${GameConfig.maxCardsPerPlayer} cards'),
            _buildSettingRow('Min Card Cost', '${GameConfig.minCardCost} ETB'),
            _buildSettingRow('Max Card Cost', '${GameConfig.maxCardCost} ETB'),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSettingsCard() {
    return Card(
      color: const Color(0xFF1C1C3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Configuration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingRow('Retry Delays', '${GameConfig.retryDelays.join('ms, ')}ms'),
            _buildSettingRow('Real-time Sync Timeout', '${GameConfig.realTimeSyncTimeout.inSeconds}s'),
            _buildSettingRow('SnackBar Duration', '${GameConfig.snackBarDuration.inSeconds}s'),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitCalculator() {
    return Card(
      color: const Color(0xFF1C1C3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profit Calculator',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildCalculatorExample(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculatorExample() {
    // Example calculations
    const exampleCards = 50;
    const exampleCost = 10.0;
    const exampleWinners = 2;
    
    final breakdown = ProfitBreakdown(
      totalPool: exampleCards * exampleCost,
      winnerCount: exampleWinners,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Example: $exampleCards cards × $exampleCost ETB',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            breakdown.toString(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
