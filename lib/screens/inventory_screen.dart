import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../widgets/emoji_model.dart';
import '../services/storage_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.inventory});

  final List<EmojiInventoryItem> inventory;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _activeTab = 0;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Set up haptic feedback on page load
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalPoints = widget.inventory.fold(0, (sum, item) => sum + item.points);
    final byTier = {
      1: widget.inventory.where((item) => item.tier == 1).toList(),
      2: widget.inventory.where((item) => item.tier == 2).toList(),
      3: widget.inventory.where((item) => item.tier == 3).toList(),
    };
    
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: const Color(0xFF1A1F38),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                colors: [Color(0xFF00FFFF), Color(0xFFFF00FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds);
            },
            child: const Text(
              'EMOJI VAULT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
                letterSpacing: 2.0,
              ),
            ),
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.2),
                  child: Icon(
                    Icons.stacked_line_chart,
                    color: Color.lerp(
                      const Color(0xFF00FFFF),
                      const Color(0xFFFF00FF),
                      _pulseController.value,
                    ),
                  ),
                );
              },
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E21), Color(0xFF03071E)],
          ),
        ),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              height: _isExpanded ? (isSmallScreen ? 220 : 200) : (isSmallScreen ? 140 : 120),
              child: SingleChildScrollView( // Add ScrollView to handle overflow
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A5F), Color(0xFF162544)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FFFF).withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: -5,
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF00FFFF).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Add this
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatCard('TOTAL POINTS', totalPoints, Icons.emoji_events, isSmallScreen),
                              _buildStatCard('EMOJIS CAPTURED', widget.inventory.length, Icons.catching_pokemon, isSmallScreen),
                            ],
                          ),
                          if (_isExpanded) 
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0), // Increased padding
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildTierStat('TIER 1', byTier[1]?.length ?? 0, Colors.blue, isSmallScreen),
                                  _buildTierStat('TIER 2', byTier[2]?.length ?? 0, Colors.purple, isSmallScreen),
                                  _buildTierStat('TIER 3', byTier[3]?.length ?? 0, Colors.orange, isSmallScreen),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(0, isSmallScreen ? 'T1' : 'TIER 1', Colors.blue),
                    ),
                    Expanded(
                      child: _buildTabButton(1, isSmallScreen ? 'T2' : 'TIER 2', Colors.purple),
                    ),
                    Expanded(
                      child: _buildTabButton(2, isSmallScreen ? 'T3' : 'TIER 3', Colors.orange),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: [
                  _buildTierList(byTier[1] ?? [], isSmallScreen),
                  _buildTierList(byTier[2] ?? [], isSmallScreen),
                  _buildTierList(byTier[3] ?? [], isSmallScreen),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, bool isSmallScreen) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Add this
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: const Color(0xFF00FFFF),
              size: isSmallScreen ? 12 : 16, // Reduced sizes
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 9 : 11, // Reduced sizes
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              colors: [Color(0xFF00FFFF), Color(0xFFFF00FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds);
          },
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: isSmallScreen ? 20 : 24, // Reduced sizes
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Orbitron',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTierStat(String label, int count, Color color, bool isSmallScreen) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 8 : 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String title, Color color) {
    final isActive = _activeTab == index;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : Colors.grey.withOpacity(0.3),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: -2,
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? color : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTierList(List<EmojiInventoryItem> items, bool isSmallScreen) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: isSmallScreen ? 40 : 50,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'NO EMOJIS DETECTED',
              style: TextStyle(
                color: Colors.grey,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go explore to scan and capture more',
              style: TextStyle(
                color: Colors.grey,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final formattedTime = DateFormat.Hms().format(item.caughtTime);
        final formattedDate = item.caughtTime.toString().split(' ')[0];

        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getTierColor(item.tier).withOpacity(0.2),
                  Colors.black.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getTierColor(item.tier).withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: FutureBuilder<List<Placemark>>(
              future: item.caughtLocation != null
                  ? placemarkFromCoordinates(
                      item.caughtLocation!.latitude,
                      item.caughtLocation!.longitude,
                    )
                  : Future.value([]),
              builder: (context, snapshot) {
                String locationText = 'UNKNOWN';
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final place = snapshot.data!.first;
                  locationText = '${place.locality ?? ''}, ${place.country ?? ''}';
                  // Trim long location names
                  if (locationText.length > 20 && isSmallScreen) {
                    locationText = '${locationText.substring(0, 17)}...';
                  }
                }

                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Emoji section
                      _buildHolographicEmoji(item, isSmallScreen),
                      const SizedBox(width: 10),
                      
                      // Main content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Points and power indicator row
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 6 : 8, 
                                    vertical: isSmallScreen ? 2 : 4
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getTierColor(item.tier).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _getTierColor(item.tier),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${item.points} PTS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 12 : 14,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                           if (!isSmallScreen) _buildEmojiCounter(item), // Replace _buildPowerIndicator here
                              ],
                            ),
                            
                            const SizedBox(height: 6),
                            
                            // Date captured
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: isSmallScreen ? 12 : 14,
                                  color: Colors.cyan,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    isSmallScreen 
                                        ? formattedDate 
                                        : 'CAPTURED: $formattedDate $formattedTime',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: isSmallScreen ? 10 : 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Location data
                            if (item.caughtLocation != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: isSmallScreen ? 12 : 14,
                                      color: Colors.cyan,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        locationText,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: isSmallScreen ? 10 : 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Tier indicator
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black45,
                          border: Border.all(
                            color: _getTierColor(item.tier),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '${item.tier}',
                          style: TextStyle(
                            color: _getTierColor(item.tier),
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 10 : 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHolographicEmoji(EmojiInventoryItem item, bool isSmallScreen) {
    return Container(
      width: isSmallScreen ? 45 : 55,
      height: isSmallScreen ? 45 : 55,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _getTierColor(item.tier).withOpacity(0.8),
            Colors.black,
          ],
          radius: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: _getTierColor(item.tier).withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              colors: [
                Colors.white,
                _getTierColor(item.tier),
                Colors.white,
              ],
              stops: const [0.1, 0.5, 0.9],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              tileMode: TileMode.mirror,
            ).createShader(bounds);
          },
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.1),
                child: Text(
                  item.emoji,
                  style: TextStyle(fontSize: isSmallScreen ? 24 : 30),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiCounter(EmojiInventoryItem item) {
    final count = widget.inventory
        .where((i) => i.emoji == item.emoji)
        .length;
        
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getTierColor(item.tier).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getTierColor(item.tier).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.emoji,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            '×$count',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Orbitron',
              shadows: [
                Shadow(
                  color: _getTierColor(item.tier).withOpacity(0.5),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(int tier) {
    switch (tier) {
      case 1: return const Color(0xFF29B6F6); // Bright blue
      case 2: return const Color(0xFFAB47BC); // Bright purple
      case 3: return const Color(0xFFFF9800); // Bright orange
      default: return Colors.grey;
    }
  }
}