import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/card_box.dart';
import '../widgets/fake_bar_chart.dart';
import '../widgets/kpi_card.dart';
import '../widgets/data_table_card.dart';
import '../widgets/app_colors.dart';
import '../widgets/notification_bell.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.onOpenNotifications,
  });

  final VoidCallback onOpenNotifications;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime(2024, 5, 1),
    end: DateTime(2024, 12, 31),
  );

  Future<void> _selectDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chọn khoảng thời gian',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      saveText: 'Lưu',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedDateRange = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _DashboardHeader(
            dateRange: _selectedDateRange,
            onSelectDateRange: _selectDateRange,
            onOpenNotifications: widget.onOpenNotifications,
          ),
          const SizedBox(height: 22),
          const Row(
            children: [
              KpiCard(
                  title: 'Forest Owners',
                  value: '128',
                  icon: Icons.groups_rounded,
                  color: Color(0xff17a64a),
                  percent: '+12% vs last year'),
              SizedBox(width: 14),
              KpiCard(
                  title: 'Forest Projects',
                  value: '156',
                  icon: Icons.map_rounded,
                  color: Color(0xff2b8de8),
                  percent: '+8% vs last year'),
              SizedBox(width: 14),
              KpiCard(
                  title: 'Total Area',
                  value: '12,543.65 ha',
                  icon: Icons.eco_rounded,
                  color: Color(0xff00a651),
                  percent: '+15% vs last year'),
              SizedBox(width: 14),
              KpiCard(
                  title: 'Total Trees',
                  value: '8,956,231',
                  icon: Icons.park_rounded,
                  color: Color(0xff8e44ec),
                  percent: '+10% vs last year'),
              SizedBox(width: 14),
              KpiCard(
                  title: 'Estimated Carbon',
                  value: '215,430 tCO₂e',
                  icon: Icons.cloud_queue,
                  color: Color(0xffffa726),
                  percent: '+20% vs last year'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 5,
                  child: CardBox(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                        Text('Area by Province',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.text)),
                        SizedBox(height: 18),
                        _DonutArea()
                      ]))),
              const SizedBox(width: 20),
              Expanded(
                  flex: 6,
                  child: CardBox(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                        Text('Estimated Carbon by Project (tCO₂e)',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.text)),
                        SizedBox(height: 12),
                        FakeBarChart()
                      ]))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(flex: 6, child: _RecentActivities()),
              SizedBox(width: 20),
              Expanded(flex: 5, child: _ProjectMapPreview()),
            ],
          ),
        ],
      ),
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
        final compact = constraints.maxWidth < 860;

        final title = const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        );

        final actions = Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _DateRangeBox(
              dateRange: dateRange,
              onTap: onSelectDateRange,
            ),
            NotificationBell(
              onOpenAll: onOpenNotifications,
            ),
            _UserBox(
              displayName: displayName,
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              title,
              const SizedBox(height: 14),
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
          height: 54,
          constraints: const BoxConstraints(minWidth: 265),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
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
      height: 54,
      constraints: const BoxConstraints(
        minWidth: 195,
        maxWidth: 260,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
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

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';
}

class _DonutArea extends StatelessWidget {
  const _DonutArea();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 34,
                  color: Colors.teal.shade200,
                  backgroundColor: Colors.green.shade100),
              SizedBox(
                  width: 190,
                  height: 190,
                  child: CircularProgressIndicator(
                      value: .78,
                      strokeWidth: 34,
                      color: AppColors.primary,
                      backgroundColor: Colors.transparent)),
              SizedBox(
                  width: 158,
                  height: 158,
                  child: CircularProgressIndicator(
                      value: .42,
                      strokeWidth: 34,
                      color: Colors.orange,
                      backgroundColor: Colors.transparent)),
              const Text('12,543.65\nha',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: AppColors.text)),
            ],
          ),
        ),
        const SizedBox(width: 26),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Legend(
                    color: AppColors.primary,
                    text: 'Lam Dong      3,245.50 ha (25.9%)'),
                _Legend(
                    color: Color(0xff4dbb75),
                    text: 'Gia Lai          2,875.30 ha (22.9%)'),
                _Legend(
                    color: Color(0xff2b8de8),
                    text: 'Dak Lak        2,210.15 ha (17.8%)'),
                _Legend(
                    color: Colors.orange,
                    text: 'Quang Tri     1,845.40 ha (14.7%)'),
                _Legend(
                    color: Colors.teal,
                    text: 'Others          1,046.80 ha (8.4%)'),
              ]),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.text))
      ]));
}

class _RecentActivities extends StatelessWidget {
  const _RecentActivities();
  @override
  Widget build(BuildContext context) => DataTableCard(columns: const [
        'Date',
        'Project',
        'Activity Type',
        'User',
        'Location',
        'Photos'
      ], rows: const [
        [
          '20/05/2024',
          'Dak Lak Project 01',
          'Planting',
          'Nguyễn Văn A',
          'Dak Lak',
          '+3'
        ],
        [
          '18/05/2024',
          'Lam Dong Project 02',
          'Maintenance',
          'Tran Thi B',
          'Lam Dong',
          '+2'
        ],
        [
          '15/05/2024',
          'Gia Lai Project 01',
          'Patrol',
          'Le Van C',
          'Gia Lai',
          '+4'
        ],
        [
          '12/05/2024',
          'Quang Tri Project 01',
          'Fertilizing',
          'Pham Van D',
          'Quang Tri',
          '+1'
        ],
      ]);
}

class _ProjectMapPreview extends StatelessWidget {
  const _ProjectMapPreview();
  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Project Map Overview',
            style:
                TextStyle(fontWeight: FontWeight.w900, color: AppColors.text)),
        const SizedBox(height: 14),
        Container(
          height: 260,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                  colors: [Color(0xff0b5d38), Color(0xff113d2c)])),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _MapLinesPainter())),
            const Positioned(
                left: 95,
                top: 85,
                child: Icon(Icons.location_on, color: Colors.white, size: 44)),
            const Positioned(
                right: 92,
                top: 55,
                child: Icon(Icons.location_on, color: Colors.white, size: 44)),
            const Positioned(
                left: 235,
                bottom: 55,
                child: Icon(Icons.location_on, color: Colors.white, size: 44)),
            Positioned(
                right: 14,
                bottom: 14,
                child: Column(children: [
                  _mapBtn(Icons.add),
                  const SizedBox(height: 6),
                  _mapBtn(Icons.remove)
                ])),
          ]),
        ),
      ]),
    );
  }

  static Widget _mapBtn(IconData icon) => Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 18, color: AppColors.text));
}

class _MapLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(.18);
    for (var i = 0; i < 12; i++) {
      final y = size.height / 12 * i;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y + (i.isEven ? 30 : -20)), paint);
    }
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.lightGreenAccent.withOpacity(.55);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(55, 38, 135, 118), const Radius.circular(28)),
        border);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(210, 68, 140, 130), const Radius.circular(28)),
        border..color = Colors.purpleAccent.withOpacity(.5));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(350, 34, 135, 120), const Radius.circular(28)),
        border..color = Colors.blueAccent.withOpacity(.5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
