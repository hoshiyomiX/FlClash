import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/widgets/sheet.dart';
import 'package:flutter/material.dart';

class CommonScaffoldBackActionProvider extends InheritedWidget {
  final VoidCallback? backAction;

  const CommonScaffoldBackActionProvider({
    super.key,
    required this.backAction,
    required super.child,
  });

  static CommonScaffoldBackActionProvider? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CommonScaffoldBackActionProvider>();
  }

  @override
  bool updateShouldNotify(CommonScaffoldBackActionProvider oldWidget) =>
      backAction != oldWidget.backAction;
}

class CommonScaffoldFabExtendedProvider extends InheritedWidget {
  final bool isExtended;

  const CommonScaffoldFabExtendedProvider({
    super.key,
    required this.isExtended,
    required super.child,
  });

  static CommonScaffoldFabExtendedProvider? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<
          CommonScaffoldFabExtendedProvider
        >();
  }

  @override
  bool updateShouldNotify(CommonScaffoldFabExtendedProvider oldWidget) =>
      isExtended != oldWidget.isExtended;
}

class ItemPositionProvider extends InheritedWidget {
  final ItemPosition position;

  const ItemPositionProvider({
    super.key,
    required this.position,
    required super.child,
  });

  static ItemPositionProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ItemPositionProvider>();
  }

  @override
  bool updateShouldNotify(ItemPositionProvider oldWidget) =>
      position != oldWidget.position;
}

class SheetTypeProvider extends InheritedWidget {
  final SheetType type;

  const SheetTypeProvider({
    super.key,
    required super.child,
    required this.type,
  });

  static SheetTypeProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SheetTypeProvider>();
  }

  @override
  bool updateShouldNotify(SheetTypeProvider oldWidget) =>
      type != oldWidget.type;
}
