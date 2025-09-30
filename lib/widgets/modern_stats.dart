import 'package:flutter/material.dart';

class ModernStatsGrid extends StatelessWidget {
  final List<StatItem> stats;
  final int crossAxisCount;

  const ModernStatsGrid({
    super.key,
    required this.stats,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.5,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final stat = stats[index];
          return StatCard(
            title: stat.title,
            value: stat.value,
            icon: stat.icon,
            color: stat.color,
            trend: stat.trend,
            onTap: stat.onTap,
          );
        },
      ),
    );
  }
}

class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final StatTrend? trend;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.trend,
    this.onTap,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.color ?? Theme.of(context).colorScheme.primary;
    
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withOpacity(0.8),
                primaryColor,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        if (widget.trend != null) _buildTrendIndicator(context),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.value,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(BuildContext context) {
    if (widget.trend == null) return const SizedBox.shrink();

    final isPositive = widget.trend!.isPositive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            widget.trend!.percentage,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final StatTrend? trend;
  final VoidCallback? onTap;

  const StatItem({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.trend,
    this.onTap,
  });
}

class StatTrend {
  final String percentage;
  final bool isPositive;

  const StatTrend({
    required this.percentage,
    required this.isPositive,
  });
}
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(BuildContext context) {
    if (trend == null) return const SizedBox.shrink();

    IconData trendIcon;
    Color trendColor;

    switch (trend!.type) {
      case TrendType.up:
        trendIcon = Icons.trending_up;
        trendColor = Colors.green;
        break;
      case TrendType.down:
        trendIcon = Icons.trending_down;
        trendColor = Colors.red;
        break;
      case TrendType.stable:
        trendIcon = Icons.trending_flat;
        trendColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trendIcon,
            size: 12,
            color: trendColor,
          ),
          const SizedBox(width: 2),
          Text(
            trend!.value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressStatCard extends StatelessWidget {
  final String title;
  final int current;
  final int total;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const ProgressStatCard({
    super.key,
    required this.title,
    required this.current,
    required this.total,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? Theme.of(context).colorScheme.primary;
    final progress = total > 0 ? current / total : 0.0;
    
    return CustomCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$current/$total',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: primaryColor.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

class CircularStatCard extends StatelessWidget {
  final String title;
  final String value;
  final double percentage;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const CircularStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.percentage,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? Theme.of(context).colorScheme.primary;
    
    return CustomCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 6,
                  backgroundColor: primaryColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
              Column(
                children: [
                  Icon(
                    icon,
                    color: primaryColor,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${percentage.round()}%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final StatTrend? trend;
  final VoidCallback? onTap;

  const StatItem({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.trend,
    this.onTap,
  });
}

class StatTrend {
  final TrendType type;
  final String value;

  const StatTrend({
    required this.type,
    required this.value,
  });
}

enum TrendType { up, down, stable }
