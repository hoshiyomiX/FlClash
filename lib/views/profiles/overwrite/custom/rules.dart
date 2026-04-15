import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/overwrite/rule.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class CustomRulesView extends ConsumerStatefulWidget {
  final int profileId;

  const CustomRulesView(this.profileId, {super.key});

  @override
  ConsumerState createState() => _CustomRulesViewState();
}

class _CustomRulesViewState extends ConsumerState<CustomRulesView>
    with UniqueKeyStateMixin {
  int get _profileId => widget.profileId;

  @override
  void initState() {
    super.initState();
  }

  void _handleReorder(int oldIndex, int newIndex) {
    ref
        .read(profileCustomRulesProvider(_profileId).notifier)
        .order(oldIndex, newIndex);
  }

  void _handleSelected(int ruleId) {
    ref.read(itemsProvider(key).notifier).update((selectedRules) {
      final newSelectedRules = Set<int>.from(selectedRules)
        ..addOrRemove(ruleId);
      return newSelectedRules;
    });
  }

  void _handleSelectAll() {
    final ids =
        ref
            .read(profileCustomRulesProvider(_profileId))
            .value
            ?.map((item) => item.id)
            .toSet() ??
        {};
    ref.read(itemsProvider(key).notifier).update((selected) {
      return selected.containsAll(ids) ? {} : ids;
    });
  }

  Future<void> _handleDelete() async {
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteMultipTip(appLocalizations.rule),
      ),
    );
    if (res != true) {
      return;
    }
    final selectedRules = ref.read(itemsProvider(key));
    ref
        .read(profileCustomRulesProvider(_profileId).notifier)
        .delAll(selectedRules.cast<int>());
    ref.read(itemsProvider(key).notifier).value = {};
  }

  void _handleAddOrUpdate({Rule? rule}) {
    showSheet(
      context: context,
      props: SheetProps(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        maxWidth: double.maxFinite,
      ),
      builder: (context) {
        return ProfileIdProvider(
          profileId: widget.profileId,
          child: ProviderScope(
            overrides: [
              ruleProvider.overrideWithBuild(
                (_, _) => rule ?? Rule(id: -1, value: ''),
              ),
            ],
            child: _AddOrEditRuleNestedSheet(),
          ),
        );
      },
    );
  }

  @override
  Widget build(context) {
    final rules = ref.watch(profileCustomRulesProvider(_profileId)).value ?? [];
    final selectedRules = ref.watch(itemsProvider(key));
    return CommonScaffold(
      title: appLocalizations.rule,
      actions: [
        if (selectedRules.isNotEmpty) ...[
          CommonMinIconButtonTheme(
            child: IconButton.filledTonal(
              onPressed: _handleDelete,
              icon: Icon(Icons.delete),
            ),
          ),
          SizedBox(width: 2),
        ],
        CommonMinFilledButtonTheme(
          child: selectedRules.isNotEmpty
              ? FilledButton(
                  onPressed: _handleSelectAll,
                  child: Text(appLocalizations.selectAll),
                )
              : FilledButton.tonal(
                  onPressed: _handleAddOrUpdate,
                  child: Text(appLocalizations.add),
                ),
        ),
        SizedBox(width: 8),
      ],
      body: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemBuilder: (_, index) {
          final rule = rules[index];
          final position = ItemPosition.get(index, rules.length);
          return ReorderableDelayedDragStartListener(
            key: ValueKey(rule),
            index: index,
            child: ItemPositionProvider(
              position: position,
              child: RuleItem(
                isEditing: selectedRules.isNotEmpty,
                isSelected: selectedRules.contains(rule.id),
                rule: rule,
                onSelected: () {
                  _handleSelected(rule.id);
                },
                onEdit: (rule) {
                  // _handleAddOrUpdate(rule);
                },
              ),
            ),
          );
        },
        itemExtent: ruleItemHeight,
        itemCount: rules.length,
        onReorder: _handleReorder,
      ),
    );
  }
}

class _AddOrEditRuleNestedSheet extends ConsumerStatefulWidget {
  const _AddOrEditRuleNestedSheet();

  @override
  ConsumerState<_AddOrEditRuleNestedSheet> createState() =>
      _AddOrEditRuleNestedSheetState();
}

class _AddOrEditRuleNestedSheetState
    extends ConsumerState<_AddOrEditRuleNestedSheet> {
  final GlobalKey<NavigatorState> _nestedNavigatorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleClose() async {
    final state = _nestedNavigatorKey.currentState;
    if (state != null && state.canPop()) {
      final res = await globalState.showMessage(
        message: TextSpan(text: '确定要退出当前窗口吗?'),
      );
      if (res != true) {
        return;
      }
    }
    if (context.mounted) {
      _handleExit();
    }
  }

  Future<void> _handleExit() async {
    Navigator.of(context).pop();
    // final proxyGroup = ref.read(proxyGroupProvider);
    // if (_originProxyGroup == proxyGroup) {
    //   Navigator.of(context).pop();
    //   return;
    // }
    // final res = await globalState.showMessage(
    //   message: TextSpan(text: '检测到数据有更改，是否保存'),
    // );
    // if (!mounted) {
    //   return;
    // }
    // if (res != true) {
    //   Navigator.of(context).pop();
    //   return;
    // }
    // if (_handleSaveProxyGroup(context, ref)) {
    //   Navigator.of(context).pop();
    // }
  }

  Future<void> _handlePop() async {
    final state = _nestedNavigatorKey.currentState;
    if (state != null && state.canPop()) {
      state.pop();
    } else {
      _handleExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nestedNavigator = Navigator(
      key: _nestedNavigatorKey,
      onGenerateInitialRoutes: (navigator, initialRoute) {
        return [
          PagedSheetRoute(
            builder: (context) {
              return _AddOrEditRuleView();
            },
          ),
        ];
      },
    );
    final sheetProvider = SheetProvider.of(context);
    return CommonPopScope(
      onPop: (_) async {
        _handlePop();
        return false;
      },
      child: sheetProvider!.copyWith(
        nestedNavigatorPop: ([data]) {
          Navigator.of(context).pop(data);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () async {
                  _handleClose();
                },
              ),
            ),
            SizedBox(
              width: sheetProvider.type == SheetType.sideSheet ? 400 : null,
              child: SheetViewport(
                child: PagedSheet(
                  decoration: MaterialSheetDecoration(
                    size: SheetSize.stretch,
                    color: sheetProvider.type == SheetType.bottomSheet
                        ? context.colorScheme.surfaceContainerLow
                        : context.colorScheme.surface,
                    borderRadius: sheetProvider.type == SheetType.bottomSheet
                        ? BorderRadius.vertical(top: Radius.circular(28))
                        : BorderRadius.zero,
                    clipBehavior: Clip.antiAlias,
                  ),
                  navigator: nestedNavigator,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOrEditRuleView extends ConsumerStatefulWidget {
  const _AddOrEditRuleView();

  @override
  ConsumerState<_AddOrEditRuleView> createState() => _AddOrEditRuleViewState();
}

class _AddOrEditRuleViewState extends ConsumerState<_AddOrEditRuleView> {
  Widget _buildItem({
    required Widget title,
    Widget? trailing,
    final VoidCallback? onPressed,
  }) {
    return DecorationListItem(
      onPressed: onPressed,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 16,
        children: [
          title,
          if (trailing != null)
            Flexible(
              child: IconTheme(
                data: IconThemeData(
                  size: 16,
                  color: context.colorScheme.onSurface.opacity60,
                ),
                child: Container(
                  alignment: Alignment.centerRight,
                  height: globalState.measure.bodyLargeHeight + 24,
                  child: trailing,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeItem(RuleAction action) {
    return _buildItem(title: Text('类型'), trailing: Text(action.name));
  }

  Widget _buildContentItem(String? name) {
    return _buildItem(
      title: Text('内容'),
      trailing: TextFormField(
        initialValue: name,
        keyboardType: TextInputType.name,
        onChanged: (value) {
          // ref
          //     .read(ruleProvider.notifier)
          //     .update((state) => state.copyWith(name: value));
        },
        onFieldSubmitted: (_) {
          // _handleSave();
        },
        textAlign: TextAlign.end,
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: '输入规则内容',
        ),
      ),
    );
  }

  Widget _buildTargetItem(String? target) {
    return _buildItem(title: Text('分流策略'), trailing: Text(target ?? ''));
  }

  Widget _buildNoResolveItem(bool? noResolve) {
    return _buildItem(
      title: Text('不解析主机名'),
      trailing: Switch(value: noResolve ?? false, onChanged: (_) {}),
    );
  }

  Widget _buildSrcItem(bool? src) {
    return _buildItem(
      title: Text('匹配来源IP'),
      trailing: Switch(value: src ?? false, onChanged: (_) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBottomSheet =
        SheetProvider.of(context)?.type == SheetType.bottomSheet;
    final rule = ref.watch(ruleProvider);
    final parseRule = ParsedRule.parseString(rule.value);

    final height = ref.watch(
      viewSizeProvider.select(
        (state) => isBottomSheet ? state.height * 0.65 : double.maxFinite,
      ),
    );
    return AdaptiveSheetScaffold(
      sheetTransparentToolBar: true,
      body: SizedBox(
        height: height,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(bottom: 20, top: context.sheetTopPadding),
          children: [
            generateSectionV3(
              title: '基础信息',
              items: [
                _buildTypeItem(parseRule.ruleAction),
                _buildContentItem(parseRule.content),
                _buildTargetItem(parseRule.ruleTarget),
                // _buildIconItem(proxyGroup.icon),
                // _buildHiddenItem(proxyGroup.hidden),
                // _buildDisableUDPItem(proxyGroup.disableUDP),
              ],
            ),
            // if (parseRule.ruleAction.hasParams)
            generateSectionV3(
              title: '附加参数',
              items: [
                _buildNoResolveItem(parseRule.noResolve),
                _buildSrcItem(parseRule.src),
              ],
            ),
            generateSectionV3(
              title: '操作',
              items: [
                if (rule.id != -1)
                  _buildItem(
                    title: Text(
                      '删除',
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: context.colorScheme.error,
                      ),
                    ),
                    onPressed: () {
                      // _handleDelete();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
      title: rule.id == -1 ? '添加规则' : '编辑规则',
    );
  }
}
