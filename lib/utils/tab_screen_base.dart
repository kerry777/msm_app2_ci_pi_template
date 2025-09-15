import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../translations.dart';
import '../l10n/app_localizations.dart';

abstract class TabScreenBase<T extends TabScreenBase<T>> extends StatefulWidget {
  final TabController? tabController;
  final int initialTabIndex;

  const TabScreenBase({
    super.key,
    this.tabController,
    this.initialTabIndex = 0,
  });

  @override
  State<TabScreenBase<T>> createState();
}

abstract class TabScreenBaseState<T extends TabScreenBase<T>> extends State<T> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = widget.tabController ?? TabController(
      length: getTabCount(),
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    if (widget.tabController == null) {
      _tabController.dispose();
    }
    super.dispose();
  }

  int getTabCount();
  String getTabText(int index);
  List<Widget> buildTabViews();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('stock_manage')),
        bottom: TabBar(
          controller: _tabController,
          tabs: List.generate(
            getTabCount(),
            (index) => Tab(text: getTabText(index)),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: buildTabViews(),
      ),
    );
  }
} 