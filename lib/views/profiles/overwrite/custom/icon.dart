import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class IconEditDialog extends StatefulWidget {
  final String? value;

  const IconEditDialog(this.value, {super.key});

  @override
  State<IconEditDialog> createState() => _IconEditDialogState();
}

class _IconEditDialogState extends State<IconEditDialog>
    with TickerProviderStateMixin {
  late final TextEditingController _srcController;
  StreamSubscription? _streamSubscription;
  late final _IconEditDialogStateNotifier<File?> _state;

  @override
  void initState() {
    super.initState();
    _srcController = TextEditingController(text: widget.value);
    _state = _IconEditDialogStateNotifier<File?>(
      vsync: this,
      duration: commonDuration * 2,
    );
    if (widget.value != null && widget.value!.isNotEmpty) {
      _getImageFormCache();
    }
  }

  void _handleInputChange() {
    debouncer.call('_IconEditDialogState_search', () {
      _getImageFormCache();
    });
  }

  void _getImageFormCache() {
    final text = _srcController.text;
    _streamSubscription?.cancel();
    _state.setValue(null);
    if (text.isEmpty) return;
    _streamSubscription = DefaultCacheManager().getFileStream(text).listen((
      data,
    ) {
      if (mounted && data is FileInfo) {
        _state.setValue(data.file);
      }
    });
  }

  @override
  void dispose() {
    _state.dispose();
    _streamSubscription?.cancel();
    _srcController.dispose();
    super.dispose();
  }

  void _handleSave() {
    context.safePop(_srcController.text);
  }

  @override
  Widget build(BuildContext context) {
    final dimension = globalState.measure.bodyLargeHeight + 28;
    return CommonDialog(
      title: '图标',
      actions: [
        TextButton(
          onPressed: context.safePop,
          child: Text(appLocalizations.cancel),
        ),
        TextButton(onPressed: _handleSave, child: Text(appLocalizations.save)),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox(
            height: dimension,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                ListenableBuilder(
                  listenable: _state,
                  builder: (_, __) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          widthFactor: _state.layoutFactor,
                          alignment: Alignment.centerLeft,
                          child: Opacity(
                            opacity: _state.opacity.clamp(0, 1.0),
                            child: Transform.scale(
                              scale: 0.5 + (0.5 * _state.scale),
                              child: SizedBox.square(
                                dimension: dimension,
                                child: _state.value != null
                                    ? CommonCard(
                                        padding: EdgeInsets.all(6),
                                        child: CommonImage(
                                          isSvg: _srcController.text.isSvg,
                                          data: _state.value!,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12 * _state.layoutFactor),
                      ],
                    );
                  },
                ),
                Flexible(
                  child: CommonCard(
                    child: ListItem(
                      title: TextField(
                        controller: _srcController,
                        keyboardType: TextInputType.url,
                        onChanged: (_) {
                          _handleInputChange();
                        },
                        decoration: InputDecoration.collapsed(
                          border: NoInputBorder(),
                          hintText: '图标链接',
                        ),
                      ),
                    ),
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

class _IconEditDialogStateNotifier<T> extends ChangeNotifier {
  _IconEditDialogStateNotifier({
    required TickerProvider vsync,
    required Duration duration,
    T? initialValue,
  }) : _value = initialValue {
    _controller = AnimationController(vsync: vsync, duration: duration);
    _layout = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack),
    );
    _controller.addListener(notifyListeners);
  }

  late final AnimationController _controller;
  late final CurvedAnimation _layout;
  late final CurvedAnimation _opacity;
  late final CurvedAnimation _scale;

  T? _value;

  double get layoutFactor => _layout.value;

  double get opacity => _opacity.value;

  double get scale => _scale.value;

  T? get value => _value;

  void setValue(T? newValue) {
    if (newValue == null) {
      _controller.reverse().then((_) {
        _value = null;
        notifyListeners();
      });
    } else {
      _value = newValue;
      notifyListeners();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(notifyListeners);
    _controller.dispose();
    super.dispose();
  }
}
