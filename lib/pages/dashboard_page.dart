import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/dashboard_service.dart';
import '../widgets/app_colors.dart';
import '../widgets/notification_bell.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.currentUser,
    required this.onOpenNotifications,
  });

  final UserModel currentUser;
  final VoidCallback onOpenNotifications;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService _dashboardService = DashboardService();

  late DateTimeRange _selectedDateRange;
  late Stream<DashboardData> _dashboardStream;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, 1, 1),
      end: now,
    );

    _refreshDashboardStream();
  }

  void _refreshDashboardStream() {
    _dashboardStream = _dashboardService.watchDashboard(
      _selectedDateRange,
      widget.currentUser,
    );
  }

  Future<void> _selectDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chọn khoảng thời gian thống kê',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      saveText: 'Lưu',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedDateRange = selected;
      _refreshDashboardStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DashboardData>(
      stream: _dashboardStream,
      initialData: DashboardData.empty,
      builder: (context, snapshot) {
        final data = snapshot.data ?? DashboardData.empty;

        return LayoutBuilder(
          builder: (context, pageConstraints) {
            final pageWidth = pageConstraints.maxWidth;
            final pagePadding = pageWidth >= 1200
                ? 16.0
                : pageWidth >= 720
                    ? 12.0
                    : 8.0;
            final sectionGap = pageWidth >= 900 ? 14.0 : 10.0;

            return ListView(
              padding: EdgeInsets.all(pagePadding),
              children: <Widget>[
                _DashboardHeader(
                  dateRange: _selectedDateRange,
                  onSelectDateRange: _selectDateRange,
                  onOpenNotifications: widget.onOpenNotifications,
                ),
                SizedBox(height: sectionGap),
                if (snapshot.hasError) _ErrorBanner(error: snapshot.error),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    data == DashboardData.empty)
                  const LinearProgressIndicator(),
                _KpiSection(data: data),
                SizedBox(height: sectionGap),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Stack earlier so charts remain readable at 100% zoom
                    // even when a sidebar is visible.
                    final stacked = constraints.maxWidth < 980;

                    if (stacked) {
                      return Column(
                        children: <Widget>[
                          _AreaByProvinceCard(
                            values: data.areaByProvince,
                            totalArea: data.totalAreaHa,
                          ),
                          SizedBox(height: sectionGap),
                          _RecentActivitiesCard(
                            activities: data.recentActivities,
                          ),
                          SizedBox(height: sectionGap),
                          _CarbonByProjectCard(
                            values: data.carbonByProject,
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              flex: 5,
                              child: _AreaByProvinceCard(
                                values: data.areaByProvince,
                                totalArea: data.totalAreaHa,
                              ),
                            ),
                            SizedBox(width: sectionGap),
                            Expanded(
                              flex: 6,
                              child: _RecentActivitiesCard(
                                activities: data.recentActivities,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: sectionGap),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _CarbonByProjectCard(
                                values: data.carbonByProject,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.dateRange,
    required this.onSelectDateRange,
    required this.onOpenNotifications,
  });

  final DateTimeRange dateRange;
  final VoidCallback onSelectDateRange;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    final displayName = currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!.trim()
        : (currentUser?.email?.trim().isNotEmpty == true
            ? currentUser!.email!.split('@').first
            : 'Admin Platform');

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final veryCompact = width < 560;
        final compact = width < 980;

        final title = Text(
          'Dashboard',
          style: TextStyle(
            fontSize: veryCompact ? 20 : 24,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        );

        final dateBox = SizedBox(
          width: veryCompact
              ? width
              : compact
                  ? math.min(280, width * 0.54)
                  : 245,
          child: _DateRangeBox(
            dateRange: dateRange,
            onTap: onSelectDateRange,
          ),
        );

        final userBox = SizedBox(
          width: veryCompact
              ? width
              : compact
                  ? math.min(220, width * 0.38)
                  : 185,
          child: _UserBox(
            displayName: displayName,
          ),
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            dateBox,
            NotificationBell(
              onOpenAll: onOpenNotifications,
            ),
            userBox,
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              title,
              const SizedBox(height: 12),
              actions,
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: title),
            actions,
          ],
        );
      },
    );
  }
}

class _DateRangeBox extends StatelessWidget {
  const _DateRangeBox({
    required this.dateRange,
    required this.onTap,
  });

  final DateTimeRange dateRange;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 54,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xffdfe6e1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: Color(0xff202923),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '${_formatDate(dateRange.start)} - '
                  '${_formatDate(dateRange.end)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff2d3731),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserBox extends StatelessWidget {
  const _UserBox({
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffdfe6e1),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xffffd69a),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 23,
              color: Color(0xff0b5d38),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Tooltip(
              message: displayName,
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff222b25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiSection extends StatelessWidget {
  const _KpiSection({
    required this.data,
  });

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final columns = available >= 1050
            ? 5
            : available >= 760
                ? 3
                : available >= 520
                    ? 2
                    : 1;

        final width = (available - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: <Widget>[
            _LiveKpiCard(
              width: width,
              title: 'Forest Owners',
              value: _formatInteger(data.forestOwners),
              icon: Icons.groups_rounded,
              color: const Color(0xff17a64a),
            ),
            _LiveKpiCard(
              width: width,
              title: 'Forest Projects',
              value: _formatInteger(data.forestProjects),
              icon: Icons.map_rounded,
              color: const Color(0xff2b8de8),
            ),
            _LiveKpiCard(
              width: width,
              title: 'Total Area',
              value: '${_formatNumber(data.totalAreaHa)} ha',
              icon: Icons.eco_rounded,
              color: const Color(0xff00a651),
            ),
            _LiveKpiCard(
              width: width,
              title: 'Total Trees',
              value: _formatInteger(data.totalTrees),
              icon: Icons.park_rounded,
              color: const Color(0xff8e44ec),
            ),
            _LiveKpiCard(
              width: width,
              title: 'Estimated Carbon',
              value: '${_formatNumber(data.estimatedCarbonTon)} tCO₂e',
              icon: Icons.cloud_queue,
              color: const Color(0xffffa726),
            ),
          ],
        );
      },
    );
  }
}

class _LiveKpiCard extends StatelessWidget {
  const _LiveKpiCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(
        minHeight: 92,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffe2e9e4),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 21,
              color: color,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9.2,
                    color: Color(0xff6f7c74),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Tooltip(
                  message: value,
                  child: SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 16.5,
                          height: 1.1,
                          color: Color(0xff17211b),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Cập nhật từ Firebase',
                  style: TextStyle(
                    fontSize: 8.6,
                    color: Color(0xff169149),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaByProvinceCard extends StatelessWidget {
  const _AreaByProvinceCard({
    required this.values,
    required this.totalArea,
  });

  final List<DashboardProvinceArea> values;
  final double totalArea;

  static const List<Color> _colors = <Color>[
    Color(0xff08783f),
    Color(0xff2baa62),
    Color(0xff4dbb75),
    Color(0xff2b8de8),
    Color(0xffffb020),
    Color(0xff5aa7a0),
    Color(0xff805ad5),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = values.take(6).toList();

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Area by Province',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const _EmptyChart(
              message: 'Chưa có dữ liệu diện tích theo tỉnh.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 500;

                final chartSize = math.max(
                  150.0,
                  math.min(
                    185.0,
                    stacked
                        ? constraints.maxWidth * 0.58
                        : constraints.maxWidth * 0.40,
                  ),
                );

                final chart = SizedBox(
                  width: chartSize,
                  height: chartSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CustomPaint(
                        size: Size(chartSize, chartSize),
                        painter: _DonutChartPainter(
                          values: shown.map((item) => item.areaHa).toList(),
                          colors: _colors,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _formatNumber(totalArea),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                            ),
                          ),
                          const Text(
                            'ha',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xff748078),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                final legend = Column(
                  children: shown.asMap().entries.map(
                    (entry) {
                      final item = entry.value;
                      final percent =
                          totalArea <= 0 ? 0 : item.areaHa / totalArea * 100;

                      return _LegendRow(
                        color: _colors[entry.key % _colors.length],
                        label: item.province,
                        value: '${_formatNumber(item.areaHa)} ha '
                            '(${percent.toStringAsFixed(1)}%)',
                      );
                    },
                  ).toList(),
                );

                if (stacked) {
                  return Column(
                    children: <Widget>[
                      chart,
                      const SizedBox(height: 12),
                      legend,
                    ],
                  );
                }

                return Row(
                  children: <Widget>[
                    chart,
                    const SizedBox(width: 24),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({
    required this.values,
    required this.colors,
  });

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(
      0,
      (sum, value) => sum + value,
    );

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );
    final shortestSide = math.min(
      size.width,
      size.height,
    );
    final strokeWidth = math.max(
      20.0,
      shortestSide * 0.15,
    );
    final radius = shortestSide / 2 - strokeWidth / 2 - 4;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (total <= 0) {
      paint.color = const Color(0xffe8eeea);
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        paint,
      );
      return;
    }

    double startAngle = -math.pi / 2;

    for (int index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;

      paint.color = colors[index % colors.length];

      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        paint,
      );

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(
    covariant _DonutChartPainter oldDelegate,
  ) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 300;

        return Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xff718078),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              value,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xff718078),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CarbonByProjectCard extends StatefulWidget {
  const _CarbonByProjectCard({
    required this.values,
  });

  final List<DashboardProjectCarbon> values;

  @override
  State<_CarbonByProjectCard> createState() => _CarbonByProjectCardState();
}

class _CarbonByProjectCardState extends State<_CarbonByProjectCard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Estimated Carbon by Project (tCO₂e)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 18),
          if (widget.values.isEmpty)
            const _EmptyChart(
              message: 'Chưa có dữ liệu carbon theo dự án.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final maxValue = widget.values
                    .map((item) => item.co2eTon)
                    .fold<double>(0, math.max);

                if (constraints.maxWidth < 560) {
                  return Column(
                    children: widget.values.map((item) {
                      final progress =
                          maxValue <= 0 ? 0.0 : item.co2eTon / maxValue;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Tooltip(
                                    message: item.projectName,
                                    child: Text(
                                      item.projectName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xff354239),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatCompactNumber(
                                    item.co2eTon,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xff354239),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0, 1),
                                minHeight: 12,
                                backgroundColor: const Color(0xffe8efe9),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }

                final useScroll = widget.values.length > 5;
                final itemWidth = useScroll ? constraints.maxWidth / 5.5 : constraints.maxWidth / widget.values.length;

                final chartContent = SizedBox(
                  height: 220,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: widget.values.map((item) {
                      final barHeight =
                          maxValue <= 0 ? 0.0 : item.co2eTon / maxValue * 175;

                      final child = Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              _formatCompactNumber(
                                item.co2eTon,
                              ),
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff354239),
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedContainer(
                              duration: const Duration(
                                milliseconds: 350,
                              ),
                              height: math.max(barHeight, 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Tooltip(
                              message: item.projectName,
                              child: Text(
                                item.projectName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  height: 1.2,
                                  color: Color(0xff5f6c64),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (useScroll) {
                        return SizedBox(
                          width: itemWidth,
                          child: child,
                        );
                      }

                      return Expanded(child: child);
                    }).toList(),
                  ),
                );

                if (useScroll) {
                  return Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: chartContent,
                      ),
                    ),
                  );
                }

                return chartContent;
              },
            ),
        ],
      ),
    );
  }
}

class _RecentActivitiesCard extends StatelessWidget {
  const _RecentActivitiesCard({
    required this.activities,
  });

  final List<DashboardActivity> activities;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Recent Activities',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 14),
          if (activities.isEmpty)
            const _EmptyChart(
              message: 'Chưa có nhật ký hiện trường.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 620) {
                  return Column(
                    children: activities.map(_activityCard).toList(),
                  );
                }

                return Table(
                  border: const TableBorder(
                    horizontalInside: BorderSide(
                      color: Color(0xffe7ede9),
                      width: 0.8,
                    ),
                  ),
                  columnWidths: const <int, TableColumnWidth>{
                    0: FlexColumnWidth(0.85),
                    1: FlexColumnWidth(1.35),
                    2: FlexColumnWidth(0.95),
                    3: FlexColumnWidth(0.95),
                    4: FlexColumnWidth(0.85),
                    5: FlexColumnWidth(0.45),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: <TableRow>[
                    TableRow(
                      decoration: const BoxDecoration(
                        color: Color(0xfff7faf8),
                      ),
                      children: const <Widget>[
                        _TableHeader('Date'),
                        _TableHeader('Project'),
                        _TableHeader('Activity'),
                        _TableHeader('User'),
                        _TableHeader('Location'),
                        _TableHeader('Photos'),
                      ],
                    ),
                    ...activities.map(
                      (activity) => TableRow(
                        children: <Widget>[
                          _TableCell(
                            activity.date == null
                                ? '-'
                                : _formatDate(
                                    activity.date!,
                                  ),
                          ),
                          _TableCell(activity.project),
                          _TableCell(
                            activity.activityType,
                          ),
                          _TableCell(activity.user),
                          _TableCell(activity.location),
                          _TableCell(
                            '+${activity.photoCount}',
                            centered: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _activityCard(DashboardActivity activity) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfffafcfb),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xffe3eae5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            activity.activityType.isEmpty ? 'Hoạt động' : activity.activityType,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            activity.project.isEmpty ? '-' : activity.project,
            style: const TextStyle(
              color: Color(0xff68756d),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${activity.user} • ${activity.location} • '
            '${activity.photoCount} ảnh',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xff89958d),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xff657269),
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(
    this.value, {
    this.centered = false,
  });

  final String value;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 40,
        ),
        alignment: centered ? Alignment.center : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 7,
        ),
        child: Text(
          value.isEmpty ? '-' : value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            fontSize: 10.2,
            height: 1.2,
            color: Color(0xff354239),
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 520 ? 10.0 : 12.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xffe2e9e4),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x07000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.query_stats,
              size: 42,
              color: Color(0xff9ba79f),
            ),
            const SizedBox(height: 9),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff748078),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.error,
  });

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffffeeee),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xffffcccc),
        ),
      ),
      child: Text(
        'Không thể đọc một phần dữ liệu Dashboard: $error',
        style: const TextStyle(
          color: Color(0xffb42318),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';
}

String _formatInteger(num value) {
  final raw = value.round().toString();
  final buffer = StringBuffer();

  for (int index = 0; index < raw.length; index++) {
    final reverseIndex = raw.length - index;

    buffer.write(raw[index]);

    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}

String _formatNumber(double value) {
  if (value == 0) return '0';

  final decimals = value == value.roundToDouble() ? 0 : 2;
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final integer = _formatInteger(
    int.tryParse(parts.first) ?? 0,
  );

  if (parts.length == 1) return integer;

  return '$integer.${parts.last}';
}

String _formatCompactNumber(double value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }

  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }

  return _formatNumber(value);
}
