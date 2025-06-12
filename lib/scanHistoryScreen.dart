import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';

// Simplified data model
class HistoryItem {
  final Color imageColor;
  final String title;
  final String subtitle;
  final bool isSuccess;
  final String timeAgo;

  const HistoryItem({
    required this.imageColor,
    required this.title,
    required this.subtitle,
    required this.isSuccess,
    required this.timeAgo,
  });
}

// Main screen
class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 640;

    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: AppColors.defaultbackground,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 27.0),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.black,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text(
          'Scan History',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 28,
            color: Color(0xFF0B8FAC),
          ),
        ),
        centerTitle: true,
        toolbarHeight: 80,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 23,
          vertical: 20,
        ),
        child: Column(
          children: [
            _buildHistorySection('06 May, 2025', [
              const HistoryItem(
                imageColor: Color(0xFFF4A261),
                title: 'ipdom dolor',
                subtitle: 'ipdom dolor',
                isSuccess: false,
                timeAgo: '5 hrs ago',
              ),
              const HistoryItem(
                imageColor: Color(0xFFE9C46A),
                title: 'ipdom dolor',
                subtitle: 'ipdom dolor',
                isSuccess: true,
                timeAgo: '5 hrs ago',
              ),
            ], isSmallScreen),
            const SizedBox(height: 23),
            _buildHistorySection('01 May, 2025', [
              const HistoryItem(
                imageColor: Color(0xFF2A9D8F),
                title: 'ipdom dolor',
                subtitle: 'ipdom dolor',
                isSuccess: false,
                timeAgo: '5 hrs ago',
              ),
              const HistoryItem(
                imageColor: Color(0xFF264653),
                title: 'ipdom dolor',
                subtitle: 'ipdom dolor',
                isSuccess: false,
                timeAgo: '5 hrs ago',
              ),
              const HistoryItem(
                imageColor: Color(0xFFF1FAEE),
                title: 'ipdom dolor',
                subtitle: 'ipdom dolor',
                isSuccess: true,
                timeAgo: '5 hrs ago',
              ),
            ], isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(
    String date,
    List<HistoryItem> items,
    bool isSmallScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          date,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
            fontSize: isSmallScreen ? 14 : 16,
            color: const Color(0xFF1D2939),
            letterSpacing: -0.45,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildHistoryCard(item, isSmallScreen),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(HistoryItem item, bool isSmallScreen) {
    final cardHeight = isSmallScreen ? 76.0 : 84.0;
    final imageSize = isSmallScreen ? 48.0 : 53.0;

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Product image
          Padding(
            padding: EdgeInsets.only(
              left: isSmallScreen ? 15 : 17,
              top: isSmallScreen ? 14 : 15,
            ),
            child: Container(
              width: imageSize,
              height: isSmallScreen ? 47 : 52,
              decoration: BoxDecoration(
                color: item.imageColor,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 16, 60, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF494949),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                      fontSize: 10,
                      color: Color(0xFF6C8797),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Status and time
          Padding(
            padding: EdgeInsets.only(right: isSmallScreen ? 12 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 8),
                _buildStatusIcon(item.isSuccess),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 10,
                      color: Color(0xFF6C8797),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      item.timeAgo,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 7,
                        color: Color(0xFF6C8797),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool isSuccess) {
    if (isSuccess) {
      return Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: AppColors.mild,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 12),
      );
    } else {
      return Container(
        width: 20,
        height: 18,
        decoration: const BoxDecoration(
          color: AppColors.dangerAlert,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.warning, color: Colors.white, size: 12),
      );
    }
  }
}
