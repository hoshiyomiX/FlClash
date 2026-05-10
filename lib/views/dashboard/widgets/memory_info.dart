import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// S-05: Moved global ValueNotifier to instance-level inside widget state
// No more leaked global ValueNotifier or orphan timers

class MemoryInfo extends StatefulWidget {
  const MemoryInfo({super.key});

  @override
  State<MemoryInfo> createState() => _MemoryInfoState();
}

class _MemoryInfoState extends State<MemoryInfo> with WidgetsBindingObserver {
  // S-05: Instance-level ValueNotifier instead of leaked global
  final _memoryNotifier = ValueNotifier<num>(0);
  Timer? _timer;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateMemory();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _memoryNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // S-05: Pause timer when app goes to background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isVisible = state == AppLifecycleState.resumed;
    if (!_isVisible) {
      _timer?.cancel();
      _timer = null;
    } else {
      _updateMemory();
    }
  }

  Future<void> _updateMemory() async {
    if (!_isVisible) return;
    final rss = ProcessInfo.currentRss;
    if (coreController.isCompleted) {
      _memoryNotifier.value = await coreController.getMemory() + rss;
    } else {
      _memoryNotifier.value = rss;
    }
    // S-05: Increased from 2s to 10s for battery optimization
    _timer = Timer(const Duration(seconds: 10), () async {
      _updateMemory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(iconData: Icons.memory, label: appLocalizations.memoryInfo),
        onPressed: () {
          coreController.requestGc();
        },
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: globalState.measure.bodyMediumHeight + 2,
                child: ValueListenableBuilder(
                  valueListenable: _memoryNotifier,
                  builder: (_, memory, _) {
                    final traffic = memory.traffic;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          traffic.value,
                          style: context.textTheme.bodyMedium?.toLight
                              .adjustSize(1),
                        ),
                        SizedBox(width: 8),
                        Text(
                          traffic.unit,
                          style: context.textTheme.bodyMedium?.toLight
                              .adjustSize(1),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
