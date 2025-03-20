import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import '../../../core/theme/theme.dart';
import '../../layout/main_layout.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedPeriod = 'month'; // 'month' or 'all'

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      pageTitle: 'Dashboard',
      child: Column(
        children: [
          // Period Selector - More compact and higher up
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withAlpha(25),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPeriodOption('Ciclo', 'month'),
                          Container(
                            width: 1,
                            height: 32,
                            color: Colors.white.withAlpha(25),
                          ),
                          _buildPeriodOption('Total', 'all'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEarningsCard(),
                  const SizedBox(height: 24),
                  _buildEarningsGraph(),
                  const SizedBox(height: 24),
                  _buildStatsGrid(),
                  const SizedBox(height: 24),
                  _buildProcessesSection(),
                  const SizedBox(height: 24),
                  _buildSubmissionsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodOption(String label, String value) {
    final isSelected = _selectedPeriod == value;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = value),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        color: isSelected ? AppTheme.primary.withAlpha(38) : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.primary : Colors.white.withAlpha(178),
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsCard() {
    final bool isCurrentCycle = _selectedPeriod == 'month';
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(38),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primary.withAlpha(50),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comissões',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isCurrentCycle ? '€ 5.280,00' : '€ 42.150,00',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
              if (isCurrentCycle) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.arrow_up_right,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+22% em relação ao ciclo anterior',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsGraph() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withAlpha(25),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evolução de Comissões',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _selectedPeriod == 'month' 
                          ? [
                              const FlSpot(0, 1500),
                              const FlSpot(1, 2300),
                              const FlSpot(2, 1800),
                              const FlSpot(3, 3200),
                              const FlSpot(4, 2800),
                              const FlSpot(5, 5280),
                            ]
                          : [
                              const FlSpot(0, 15000),
                              const FlSpot(1, 23000),
                              const FlSpot(2, 18000),
                              const FlSpot(3, 32000),
                              const FlSpot(4, 28000),
                              const FlSpot(5, 42150),
                            ],
                        isCurved: true,
                        color: AppTheme.primary,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.primary.withAlpha(25),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Processos Ativos',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha(25),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  _buildProcessItem(
                    label: 'Em Análise',
                    value: _selectedPeriod == 'month' ? '12' : '45',
                    color: const Color(0xFF5856D6),
                  ),
                  const SizedBox(height: 12),
                  _buildProcessItem(
                    label: 'Aguardando Documentos',
                    value: _selectedPeriod == 'month' ? '8' : '23',
                    color: const Color(0xFFFF9500),
                  ),
                  const SizedBox(height: 12),
                  _buildProcessItem(
                    label: 'Pendente de Aprovação',
                    value: _selectedPeriod == 'month' ? '5' : '15',
                    color: const Color(0xFF0A84FF),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Submissões',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha(25),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  _buildProcessItem(
                    label: 'Aprovadas',
                    value: _selectedPeriod == 'month' ? '18' : '165',
                    color: const Color(0xFF34C759),
                  ),
                  const SizedBox(height: 12),
                  _buildProcessItem(
                    label: 'Rejeitadas',
                    value: _selectedPeriod == 'month' ? '3' : '12',
                    color: const Color(0xFFFF3B30),
                  ),
                  const SizedBox(height: 12),
                  _buildProcessItem(
                    label: 'Taxa de Aprovação',
                    value: _selectedPeriod == 'month' ? '86%' : '93%',
                    color: const Color(0xFF5856D6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.foreground.withAlpha(178),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final bool isCurrentCycle = _selectedPeriod == 'month';
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard(
          title: 'Clientes Ativos',
          value: isCurrentCycle ? '32' : '156',
          icon: CupertinoIcons.person_2_fill,
          color: const Color(0xFF34C759),
        ),
        _buildStatCard(
          title: 'Propostas',
          value: isCurrentCycle ? '28' : '248',
          icon: CupertinoIcons.doc_text_fill,
          color: const Color(0xFF5856D6),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withAlpha(25),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(38),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.foreground.withAlpha(178),
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
      ),
    );
  }
} 