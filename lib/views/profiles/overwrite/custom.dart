part of 'overwrite.dart';

class _CustomContent extends ConsumerWidget {
  final int profileId;

  const _CustomContent(this.profileId);

  void _handleUseDefault() async {
    final configMap = await coreController.getConfig(profileId);
    final clashConfig = ClashConfig.fromJson(configMap);
    await database.setProfileCustomData(
      profileId,
      clashConfig.proxyGroups,
      clashConfig.rules,
    );
  }

  void _handleToProxyGroupsView(BuildContext context) {
    BaseNavigator.push(context, _CustomProxyGroupsView(profileId));
  }

  void _handleToRulesView(BuildContext context) {
    BaseNavigator.push(context, _CustomRulesView(profileId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyGroupNum =
        ref.watch(proxyGroupsCountProvider(profileId)).value ?? -1;
    final ruleNum = ref.watch(customRulesCountProvider(profileId)).value ?? -1;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: Column(
            children: [InfoHeader(info: Info(label: '自定义'))],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(
          child: _MoreActionButton(
            label: '代理组',
            onPressed: () {
              _handleToProxyGroupsView(context);
            },
            trailing: Card.filled(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: BoxConstraints(minWidth: 44),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text(
                    textAlign: TextAlign.center,
                    '$proxyGroupNum',
                    style: context.textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 4)),
        SliverToBoxAdapter(
          child: _MoreActionButton(
            label: '规则',
            onPressed: () {
              _handleToRulesView(context);
            },
            trailing: Card.filled(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: BoxConstraints(minWidth: 44),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  '$ruleNum',
                  style: context.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 32)),
        if (proxyGroupNum == 0 && ruleNum == 0)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: MaterialBanner(
                elevation: 0,
                dividerColor: Colors.transparent,
                content: Text('检测到没有数据'),
                actions: [
                  CommonMinFilledButtonTheme(
                    child: FilledButton.tonal(
                      onPressed: _handleUseDefault,
                      child: Text('一键填入'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // SliverToBoxAdapter(child: SizedBox(height: 8)),
        // SliverToBoxAdapter(
        //   child: Padding(
        //     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        //     child: CommonCard(
        //       radius: 18,
        //       child: ListTile(
        //         minTileHeight: 0,
        //         minVerticalPadding: 0,
        //         titleTextStyle: context.textTheme.bodyMedium?.toJetBrainsMono,
        //         contentPadding: const EdgeInsets.symmetric(
        //           horizontal: 16,
        //           vertical: 16,
        //         ),
        //         title: Row(
        //           crossAxisAlignment: CrossAxisAlignment.center,
        //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //           children: [
        //             Flexible(
        //               child: Text('自定义规则', style: context.textTheme.bodyLarge),
        //             ),
        //             Icon(Icons.arrow_forward_ios, size: 18),
        //           ],
        //         ),
        //       ),
        //       onPressed: () {},
        //     ),
        //   ),
        // ),
      ],
    );
  }
}

class _CustomProxyGroupsView extends ConsumerWidget {
  final int profileId;

  const _CustomProxyGroupsView(this.profileId);

  void _handleReorder(WidgetRef ref, int oldIndex, int newIndex) {
    ref.read(proxyGroupsProvider(profileId).notifier).order(oldIndex, newIndex);
  }

  void _handleEditProxyGroup(BuildContext context, ProxyGroup proxyGroup) {
    showSheet(
      context: context,
      props: SheetProps(isScrollControlled: true),
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          body: _EditCustomProxyGroupView(),
          title: '编辑',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyGroups = ref.watch(proxyGroupsProvider(profileId)).value ?? [];
    return CommonScaffold(
      title: '代理组',
      body: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemBuilder: (_, index) {
          final proxyGroup = proxyGroups[index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(proxyGroup),
            index: index,
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: CommonCard(
                radius: 16,
                padding: EdgeInsets.all(16),
                onPressed: () {
                  _handleEditProxyGroup(context, proxyGroup);
                },
                child: ListTile(
                  minTileHeight: 0,
                  minVerticalPadding: 0,
                  titleTextStyle: context.textTheme.bodyMedium?.toJetBrainsMono,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  title: Text(proxyGroup.name),
                  subtitle: Text(proxyGroup.type.name),
                ),
              ),
            ),
          );
        },
        itemCount: proxyGroups.length,
        onReorder: (oldIndex, newIndex) {
          _handleReorder(ref, oldIndex, newIndex);
        },
      ),
    );
  }
}

class _EditCustomProxyGroupView extends ConsumerStatefulWidget {
  const _EditCustomProxyGroupView();

  @override
  ConsumerState createState() => _EditCustomProxyGroupViewState();
}

class _EditCustomProxyGroupViewState
    extends ConsumerState<_EditCustomProxyGroupView> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: appController.viewSize.height * 0.65,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          generateSectionV3(
            title: '通用',
            items: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                spacing: 16,
                children: [
                  Text('名称'),
                  Flexible(
                    child: TextFormField(
                      textAlign: TextAlign.end,
                      decoration: InputDecoration.collapsed(
                        border: NoInputBorder(),
                        hintText: '输入代理组名称',
                      ),
                    ),
                  ),
                ],
              ),
              Text('类型'),
              Text('图标'),
              Text('从列表中隐藏'),
              Text('禁用udp'),
            ],
          ),
          generateSectionV3(
            title: '节点',
            items: [
              Text('手动选择代理'),
              Text('包括所有代理'),
              Text('包括所有远程代理集'),
              Text('正则表达式过滤器'),
              Text('排除类型'),
              Text('预期状态'),
            ],
          ),
          generateSectionV3(
            title: '其他',
            items: [Text('测试链接'), Text('最大失败时间'), Text('懒加载'), Text('测试间隔')],
          ),
          generateSectionV3(title: '操作', items: [Text('删除')]),
        ],
      ),
    );
  }
}

class _CustomRulesView extends ConsumerStatefulWidget {
  final int profileId;

  const _CustomRulesView(this.profileId);

  @override
  ConsumerState createState() => _CustomRulesViewState();
}

class _CustomRulesViewState extends ConsumerState<_CustomRulesView> {
  final _key = utils.id;

  void _handleReorder(int oldIndex, int newIndex) {
    ref
        .read(profileCustomRulesProvider(widget.profileId).notifier)
        .order(oldIndex, newIndex);
  }

  void _handleSelected(int ruleId) {
    ref.read(selectedItemsProvider(_key).notifier).update((selectedRules) {
      final newSelectedRules = Set<int>.from(selectedRules)
        ..addOrRemove(ruleId);
      return newSelectedRules;
    });
  }

  void _handleSelectAll() {
    final ids =
        ref
            .read(profileCustomRulesProvider(widget.profileId))
            .value
            ?.map((item) => item.id)
            .toSet() ??
        {};
    ref.read(selectedItemsProvider(_key).notifier).update((selected) {
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
    final selectedRules = ref.read(selectedItemsProvider(_key));
    ref
        .read(profileCustomRulesProvider(widget.profileId).notifier)
        .delAll(selectedRules.cast<int>());
    ref.read(selectedItemsProvider(_key).notifier).value = {};
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(context) {
    final rules =
        ref.watch(profileCustomRulesProvider(widget.profileId)).value ?? [];
    final selectedRules = ref.watch(selectedItemsProvider(_key));
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
                  onPressed: () {
                    // _handleAddOrUpdate();
                  },
                  child: Text(appLocalizations.add),
                ),
        ),
        SizedBox(width: 8),
      ],
      body: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemBuilder: (_, index) {
          final rule = rules[index];
          return ReorderableDelayedDragStartListener(
            key: ObjectKey(rule),
            index: index,
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
          );
        },
        itemCount: rules.length,
        onReorder: _handleReorder,
      ),
    );
  }
}
