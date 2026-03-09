import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:flutter/material.dart';

import 'scaffold.dart';
import 'side_sheet.dart';

@immutable
class SheetProps {
  final double? maxWidth;
  final double? maxHeight;
  final bool isScrollControlled;
  final bool useSafeArea;
  final Color? backgroundColor;
  final bool blur;

  const SheetProps({
    this.maxWidth,
    this.maxHeight,
    this.backgroundColor,
    this.useSafeArea = true,
    this.isScrollControlled = false,
    this.blur = true,
  });
}

@immutable
class ExtendProps {
  final double? maxWidth;
  final bool useSafeArea;
  final bool blur;
  final bool forceFull;

  const ExtendProps({
    this.maxWidth,
    this.useSafeArea = true,
    this.blur = true,
    this.forceFull = false,
  });
}

enum SheetType { page, bottomSheet, sideSheet }

Future<T?> showSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  SheetProps props = const SheetProps(),
}) {
  final isMobile = appController.isMobile;
  return switch (isMobile) {
    true => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: props.isScrollControlled,
      builder: (_) {
        return SheetTypeProvider(
          type: SheetType.bottomSheet,
          child: builder(context),
        );
      },
      backgroundColor: props.backgroundColor,
      showDragHandle: false,
      useSafeArea: props.useSafeArea,
    ),
    false => showModalSideSheet<T>(
      useSafeArea: props.useSafeArea,
      isScrollControlled: props.isScrollControlled,
      context: context,
      backgroundColor: props.backgroundColor,
      constraints: BoxConstraints(maxWidth: props.maxWidth ?? 360),
      filter: props.blur ? commonFilter : null,
      builder: (_) {
        return SheetTypeProvider(
          type: SheetType.sideSheet,
          child: builder(context),
        );
      },
    ),
  };
}

Future<T?> showExtend<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  ExtendProps props = const ExtendProps(),
}) {
  final isMobile = appController.isMobile;
  return switch (isMobile || props.forceFull) {
    true => BaseNavigator.push(
      context,
      SheetTypeProvider(type: SheetType.page, child: builder(context)),
    ),
    false => showModalSideSheet<T>(
      useSafeArea: props.useSafeArea,
      context: context,
      constraints: BoxConstraints(maxWidth: props.maxWidth ?? 360),
      filter: props.blur ? commonFilter : null,
      builder: (context) {
        return SheetTypeProvider(
          type: SheetType.sideSheet,
          child: builder(context),
        );
      },
    ),
  };
}

class AdaptiveSheetScaffold extends StatefulWidget {
  final Widget body;
  final String title;
  final List<Widget> actions;

  const AdaptiveSheetScaffold({
    super.key,
    required this.body,
    required this.title,
    this.actions = const [],
  });

  @override
  State<AdaptiveSheetScaffold> createState() => _AdaptiveSheetScaffoldState();
}

class _AdaptiveSheetScaffoldState extends State<AdaptiveSheetScaffold> {
  @override
  Widget build(BuildContext context) {
    final backgroundColor = context.colorScheme.surface;
    final type = SheetTypeProvider.of(context)?.type ?? SheetType.bottomSheet;
    final bottomSheet = type == SheetType.bottomSheet;
    final sideSheet = type == SheetType.sideSheet;
    final appBar = AppBar(
      forceMaterialTransparency: bottomSheet ? true : false,
      automaticallyImplyLeading: bottomSheet
          ? false
          : widget.actions.isEmpty && sideSheet
          ? false
          : true,
      centerTitle: true,
      backgroundColor: backgroundColor,
      title: Text(widget.title),
      titleTextStyle: bottomSheet
          ? context.textTheme.titleLarge?.adjustSize(-4)
          : null,
      actions: genActions([
        if (widget.actions.isEmpty && sideSheet) CloseButton(),
        ...widget.actions,
      ]),
    );
    if (bottomSheet) {
      final handleSize = Size(32, 4);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 16),
            child: Container(
              alignment: Alignment.center,
              height: handleSize.height,
              width: handleSize.width,
              decoration: ShapeDecoration(
                color: context.colorScheme.onSurfaceVariant,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(handleSize.height / 2),
                ),
              ),
            ),
          ),
          Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: appBar),
          Flexible(flex: 1, child: widget.body),
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
        ],
      );
    }
    return CommonScaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      body: widget.body,
    );
  }
}
