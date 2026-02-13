/// Central configuration for game settings and profit sharing
class GameConfig {
  // Profit Sharing Configuration
  static const double winnerShareNumerator = 100.0;
  static const double adminShareNumerator = 30.0;
  static const double totalShareDenominator = 130.0;
  
  // Calculated percentages (for display)
  static double get winnerSharePercentage => (winnerShareNumerator / totalShareDenominator) * 100;
  static double get adminSharePercentage => (adminShareNumerator / totalShareDenominator) * 100;
  
  // Display values
  static String get winnerShareDisplay => '${winnerSharePercentage.toStringAsFixed(2)}%';
  static String get adminShareDisplay => '${adminSharePercentage.toStringAsFixed(2)}%';
  
  // Calculate shares from total pool
  static double calculateWinnerShare(double totalPool) {
    return totalPool * (winnerShareNumerator / totalShareDenominator);
  }
  
  static double calculateAdminShare(double totalPool) {
    return totalPool * (adminShareNumerator / totalShareDenominator);
  }
  
  static double calculatePrizePerWinner(double totalPool, int winnerCount) {
    if (winnerCount == 0) return 0.0;
    return calculateWinnerShare(totalPool) / winnerCount;
  }
  
  // Game Settings
  static const int maxRetries = 3;
  static const int transactionTimeoutSeconds = 15;
  static const int maxCardsPerPlayer = 10;
  static const double minCardCost = 1.0;
  static const double maxCardCost = 100.0;
  
  // Retry delays (exponential backoff in milliseconds)
  static const List<int> retryDelays = [1000, 2000, 4000]; // 1s, 2s, 4s
  
  // UI Settings
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration loadingDelay = Duration(milliseconds: 500);
  static const Duration realTimeSyncTimeout = Duration(seconds: 10);
}

/// Profit breakdown information for display
class ProfitBreakdown {
  final double totalPool;
  final double winnerShare;
  final double adminShare;
  final int winnerCount;
  final double prizePerWinner;
  
  ProfitBreakdown({
    required this.totalPool,
    required this.winnerCount,
  }) : winnerShare = GameConfig.calculateWinnerShare(totalPool),
       adminShare = GameConfig.calculateAdminShare(totalPool),
       prizePerWinner = GameConfig.calculatePrizePerWinner(totalPool, winnerCount);
  
  Map<String, dynamic> toMap() {
    return {
      'totalPool': totalPool,
      'winnerShare': winnerShare,
      'adminShare': adminShare,
      'winnerCount': winnerCount,
      'prizePerWinner': prizePerWinner,
      'winnerSharePercentage': GameConfig.winnerSharePercentage,
      'adminSharePercentage': GameConfig.adminSharePercentage,
    };
  }
  
  @override
  String toString() {
    return '''
Profit Breakdown:
• Total Pool: ${totalPool.toStringAsFixed(2)} ETB
• Winners Share (${GameConfig.winnerShareDisplay}): ${winnerShare.toStringAsFixed(2)} ETB
• Admin Share (${GameConfig.adminShareDisplay}): ${adminShare.toStringAsFixed(2)} ETB
• Winners: $winnerCount
• Prize Per Winner: ${prizePerWinner.toStringAsFixed(2)} ETB
    ''';
  }
}
