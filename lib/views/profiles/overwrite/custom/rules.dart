import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/overwrite/rule.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:fl_clash/models/common.dart';
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

  void _handleAddOrUpdate({ParsedRule? rule}) {
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
              ruleProvider.overrideWithBuild((_, _) => rule ?? ParsedRule()),
            ],
            child: _AddOrEditRuleNestedSheet(),
          ),
        );
      },
    );
  }

  Widget _buildItem({
    required ParsedRule rule,
    required bool isEditing,
    required bool isSelected,
    required int index,
    required int total,
    required Function() onSelected,
    required Function(ParsedRule rule) onEdit,
  }) {
    final position = ItemPosition.get(index, total);
    return ReorderableDelayedDragStartListener(
      key: ValueKey(rule),
      index: index,
      child: ItemPositionProvider(
        position: position,
        child: RuleItemV2(
          isEditing: isEditing,
          isSelected: isSelected,
          rule: rule,
          onSelected: () {
            _handleSelected(rule.id);
          },
          onEdit: (rule) {
            _handleAddOrUpdate(rule: rule);
          },
        ),
      ),
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
          final rule = ParsedRule.parse(rules[index]);
          return _buildItem(
            index: index,
            total: rules.length,
            isEditing: selectedRules.isNotEmpty,
            isSelected: selectedRules.contains(rule.id),
            rule: rule,
            onSelected: () {
              _handleSelected(rule.id);
            },
            onEdit: (rule) {
              _handleAddOrUpdate(rule: rule);
            },
          );
        },
        itemExtent: ruleItemHeight,
        itemCount: rules.length,
        proxyDecorator: (child, index, animation) {
          final rule = ParsedRule.parse(rules[index]);
          return commonProxyDecorator(
            _buildItem(
              index: index,
              total: rules.length,
              isEditing: selectedRules.isNotEmpty,
              isSelected: selectedRules.contains(rule.id),
              rule: rule,
              onSelected: () {
                _handleSelected(rule.id);
              },
              onEdit: (rule) {
                _handleAddOrUpdate(rule: rule);
              },
            ),
            index,
            animation,
          );
        },
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
  late final ParsedRule _originRule;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _originRule = ref.read(ruleProvider);
    });
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
    final rule = ref.read(ruleProvider);
    if (_originRule == rule) {
      Navigator.of(context).pop();
      return;
    }
    final res = await globalState.showMessage(
      message: TextSpan(text: '检测到数据有更改，是否保存'),
    );
    if (!mounted) {
      return;
    }
    if (res != true) {
      Navigator.of(context).pop();
      return;
    }
    if (_handleSaveRule(context, ref)) {
      Navigator.of(context).pop();
    }
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
        nestedNavigatorPop: ([_]) {
          Navigator.of(context).pop();
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

  Future<void> _handleSelectedType() async {
    final res = await Navigator.of(
      context,
    ).push(PagedSheetRoute(builder: (context) => _RuleTypeSelectedView()));
    if (res == null) {
      return;
    }
    ref
        .read(ruleProvider.notifier)
        .update((state) => state.copyWith(ruleAction: res));
  }

  Widget _buildTypeItem(RuleAction action) {
    return _buildItem(
      title: Text('类型'),
      onPressed: () {
        _handleSelectedType();
      },
      trailing: Row(
        spacing: 4,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            action.name,
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          Icon(Icons.arrow_forward_ios),
        ],
      ),
    );
  }

  Widget _buildContentItem(String? content) {
    return _buildItem(
      title: Text('内容'),
      trailing: TextFormField(
        initialValue: content,
        keyboardType: TextInputType.name,
        onChanged: (value) {
          ref
              .read(ruleProvider.notifier)
              .update((state) => state.copyWith(content: value));
        },
        textAlign: TextAlign.end,
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: '输入规则内容',
        ),
      ),
    );
  }

  Future<void> _handleSelectedRuleProvider() async {
    final res = await Navigator.of(
      context,
    ).push(PagedSheetRoute(builder: (context) => _RuleProviderSelectedView()));
    if (res == null) {
      return;
    }
    ref
        .read(ruleProvider.notifier)
        .update((state) => state.copyWith(ruleProvider: res));
  }

  Widget _buildRuleProviderItem(String? ruleProvider) {
    return _buildItem(
      title: Text('规则集'),
      onPressed: _handleSelectedRuleProvider,
      trailing: Row(
        spacing: 4,
        mainAxisSize: MainAxisSize.min,
        children: [
          TooltipText(
            text: Text(
              ruleProvider ?? '请选择规则集',
              maxLines: 1,
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios),
        ],
      ),
    );
  }

  Future<void> _handleSelectedTarget() async {
    final res = await Navigator.of(
      context,
    ).push(PagedSheetRoute(builder: (context) => _RuleTargetSelectedView()));
    if (res == null) {
      return;
    }
    ref
        .read(ruleProvider.notifier)
        .update((state) => state.copyWith(ruleTarget: res));
  }

  Widget _buildTargetItem(String? target) {
    return _buildItem(
      title: Text('分流策略'),
      onPressed: _handleSelectedTarget,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Flexible(
            flex: 1,
            child: TooltipText(
              text: Text(
                target ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios),
        ],
      ),
    );
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

  Future<void> _handleSave() async {
    if (_handleSaveRule(context, ref)) {
      context.safeNestedPop();
    }
  }

  void _handleDelete() {}

  @override
  Widget build(BuildContext context) {
    final isBottomSheet =
        SheetProvider.of(context)?.type == SheetType.bottomSheet;
    final rule = ref.watch(ruleProvider);
    final height = ref.watch(
      viewSizeProvider.select(
        (state) => isBottomSheet ? state.height * 0.60 : double.maxFinite,
      ),
    );
    return AdaptiveSheetScaffold(
      actions: [IconButtonData(icon: Icons.check, onPressed: _handleSave)],
      sheetTransparentToolBar: true,
      body: Container(
        constraints: BoxConstraints(maxHeight: height),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(bottom: 20, top: context.sheetTopPadding),
          children: [
            generateSectionV3(
              title: '基础信息',
              items: [
                _buildTypeItem(rule.ruleAction),
                if (rule.ruleAction != RuleAction.MATCH)
                  rule.ruleAction == RuleAction.RULE_SET
                      ? _buildRuleProviderItem(rule.ruleProvider)
                      : _buildContentItem(rule.content),
                _buildTargetItem(rule.ruleTarget),
              ],
            ),
            if (rule.ruleAction.hasParams)
              generateSectionV3(
                title: '附加参数',
                items: [
                  _buildNoResolveItem(rule.noResolve),
                  _buildSrcItem(rule.src),
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
                      _handleDelete();
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

class _RuleTypeSelectedView extends ConsumerWidget {
  const _RuleTypeSelectedView();

  @override
  Widget build(BuildContext context, ref) {
    final isBottomSheet =
        SheetProvider.of(context)?.type == SheetType.bottomSheet;
    final height = ref.watch(
      viewSizeProvider.select(
        (state) => isBottomSheet ? state.height * 0.70 : double.maxFinite,
      ),
    );
    final currentRuleAction = ref.watch(
      ruleProvider.select((state) => state.ruleAction),
    );
    return AdaptiveSheetScaffold(
      sheetTransparentToolBar: true,
      body: SizedBox(
        height: height,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(bottom: 20, top: context.sheetTopPadding),
          itemCount: RuleAction.values.length,
          itemBuilder: (_, index) {
            final ruleAction = RuleAction.values[index];
            final position = ItemPosition.get(index, RuleAction.values.length);
            return ItemPositionProvider(
              position: position,
              child: DecorationListItem(
                onPressed: () {
                  Navigator.of(context).pop(ruleAction);
                },
                subtitle: Text(ruleAction.desc),
                title: Text(ruleAction.name),
                trailing: ruleAction == currentRuleAction
                    ? Icon(Icons.check)
                    : null,
              ),
            );
          },
        ),
      ),
      title: '代理类型',
    );
  }
}

class _RuleTargetSelectedView extends ConsumerWidget {
  const _RuleTargetSelectedView();

  Widget _buildItem({
    required String title,
    String? subtitle,
    required ItemPosition position,
    bool isChecked = true,
    final VoidCallback? onPressed,
  }) {
    return ItemPositionProvider(
      position: position,
      child: DecorationListItem(
        onPressed: onPressed,
        subtitle: subtitle != null ? Text(subtitle) : null,
        title: TooltipText(
          text: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        trailing: isChecked ? Icon(Icons.check) : null,
      ),
    );
  }

  void _handleSelected(BuildContext context, String target) {
    Navigator.of(context).pop(target);
  }

  @override
  Widget build(BuildContext context, ref) {
    final isBottomSheet =
        SheetProvider.of(context)?.type == SheetType.bottomSheet;
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final height = ref.watch(
      viewSizeProvider.select(
        (state) => isBottomSheet ? state.height * 0.70 : double.maxFinite,
      ),
    );
    final proxyGroups = ref.watch(
      proxyGroupsProvider(profileId).select((state) => state.value ?? []),
    );
    final proxies = ref.watch(
      clashConfigProvider(
        profileId,
      ).select((state) => state.value?.proxies ?? []),
    );
    final currentRuleTarget = ref.watch(
      ruleProvider.select((state) => state.ruleTarget),
    );
    return AdaptiveSheetScaffold(
      sheetTransparentToolBar: true,
      body: SizedBox(
        height: height,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: context.sheetTopPadding),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: InfoHeader(info: Info(label: '基础策略')),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemBuilder: (_, index) {
                  final target = RuleTarget.values[index];
                  final position = ItemPosition.get(
                    index,
                    RuleTarget.values.length,
                  );
                  return _buildItem(
                    title: target.name,
                    position: position,
                    onPressed: () {
                      _handleSelected(context, target.name);
                    },
                    isChecked: currentRuleTarget == target.name ? true : false,
                  );
                },
                itemCount: RuleTarget.values.length,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: InfoHeader(info: Info(label: '策略组')),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemBuilder: (_, index) {
                  final proxyGroup = proxyGroups[index];
                  final position = ItemPosition.get(index, proxyGroups.length);
                  return _buildItem(
                    title: proxyGroup.name,
                    subtitle: proxyGroup.type.name,
                    position: position,
                    onPressed: () {
                      _handleSelected(context, proxyGroup.name);
                    },
                    isChecked: currentRuleTarget == proxyGroup.name
                        ? true
                        : false,
                  );
                },
                itemCount: proxyGroups.length,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: InfoHeader(info: Info(label: '代理')),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemBuilder: (_, index) {
                  final proxy = proxies[index];
                  final position = ItemPosition.get(index, proxies.length);
                  return _buildItem(
                    title: proxy.name,
                    subtitle: proxy.type,
                    position: position,
                    onPressed: () {
                      _handleSelected(context, proxy.name);
                    },
                    isChecked: currentRuleTarget == proxy.name ? true : false,
                  );
                },
                itemCount: proxies.length,
              ),
            ),
          ],
        ),
      ),
      title: '分流策略',
    );
  }
}

class _RuleProviderSelectedView extends ConsumerWidget {
  const _RuleProviderSelectedView();

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
              child: Container(
                alignment: Alignment.centerRight,
                height: globalState.measure.bodyLargeHeight + 24,
                child: trailing,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final isBottomSheet =
        SheetProvider.of(context)?.type == SheetType.bottomSheet;
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final height = ref.watch(
      viewSizeProvider.select(
        (state) => isBottomSheet ? state.height * 0.70 : double.maxFinite,
      ),
    );
    final ruleProviders = ref.watch(
      clashConfigProvider(
        profileId,
      ).select((state) => state.value?.ruleProviders ?? []),
    );
    final currentRuleProvider = ref.watch(
      ruleProvider.select((state) => state.ruleProvider),
    );
    return AdaptiveSheetScaffold(
      sheetTransparentToolBar: true,
      body: SizedBox(
        height: height,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(bottom: 20, top: context.sheetTopPadding),
          itemCount: ruleProviders.length,
          itemBuilder: (_, index) {
            final ruleProvider = ruleProviders[index];
            final position = ItemPosition.get(index, ruleProviders.length);
            return ItemPositionProvider(
              position: position,
              child: _buildItem(
                onPressed: () {
                  Navigator.of(context).pop(ruleProvider);
                },
                title: Text(ruleProvider),
                trailing: currentRuleProvider == ruleProvider
                    ? Icon(Icons.check)
                    : null,
              ),
            );
          },
        ),
      ),
      title: '规则集',
    );
  }
}

bool _handleSaveRule(BuildContext context, WidgetRef ref) {
  final rule = ref.read(ruleProvider);
  if ((rule.ruleAction == RuleAction.RULE_SET && rule.ruleProvider == null) ||
      (rule.ruleAction != RuleAction.RULE_SET && rule.content == null)) {
    globalState.showMessage(
      cancelable: false,
      message: TextSpan(
        text: rule.ruleAction == RuleAction.RULE_SET ? '代理集不能为空。' : '内容不能为空。',
      ),
    );
    return false;
  }
  final profileId = ProfileIdProvider.of(context)!.profileId;
  ref.read(profileCustomRulesProvider(profileId).notifier).put(rule.toRawRule);
  return true;
}
