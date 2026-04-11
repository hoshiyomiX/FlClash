import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart' hide FileInfo;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import 'icon.dart';
import 'proxies.dart';

class CustomProxyGroupsView extends ConsumerWidget {
  final int profileId;

  const CustomProxyGroupsView(this.profileId, {super.key});

  void _handleReorder(
    WidgetRef ref,
    int profileId,
    int oldIndex,
    int newIndex,
  ) {
    ref.read(proxyGroupsProvider(profileId).notifier).order(oldIndex, newIndex);
  }

  void _handleEditProxyGroup(
    BuildContext context,
    ProxyGroup proxyGroup,
    int index,
  ) {
    showSheet(
      context: context,
      props: SheetProps(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        maxWidth: double.maxFinite,
      ),
      builder: (context) {
        return ProfileIdProvider(
          profileId: profileId,
          child: ProviderScope(
            overrides: [
              proxyGroupProvider.overrideWithBuild((_, _) => proxyGroup),
            ],
            child: EditProxyGroupNestedSheet(),
          ),
        );
      },
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required ProxyGroup proxyGroup,
    required int index,
    required int total,
    required VoidCallback onPressed,
  }) {
    final position = ItemPosition.get(index, total);
    return ItemPositionProvider(
      key: ValueKey(proxyGroup.name),
      position: position,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: DecorationListItem(
          onPressed: onPressed,
          minVerticalPadding: 8,
          leading: SizedBox.square(
            dimension: 32,
            child: IconTheme.merge(
              data: IconThemeData(size: 32),
              child: CommonTargetIcon(src: proxyGroup.icon ?? ''),
            ),
          ),
          title: TooltipText(
            text: Text(
              proxyGroup.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          subtitle: Text(proxyGroup.type.name),
          trailing: ReorderableDelayedDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle),
          ),
        ),
      ),
    );
  }

  void _handleAdd(BuildContext context) {
    showSheet(
      context: context,
      props: SheetProps(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        maxWidth: double.maxFinite,
      ),
      builder: (context) {
        return ProfileIdProvider(
          profileId: profileId,
          child: ProviderScope(
            overrides: [
              proxyGroupProvider.overrideWithBuild(
                (_, _) => ProxyGroup(
                  id: snowflake.id,
                  name: '',
                  type: GroupType.Selector,
                ),
              ),
            ],
            child: EditProxyGroupNestedSheet(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyGroups = ref.watch(proxyGroupsProvider(profileId)).value ?? [];
    return CommonScaffold(
      title: '策略组',
      actions: [
        CommonMinFilledButtonTheme(
          child: FilledButton(
            onPressed: () {
              _handleAdd(context);
            },
            child: Text(appLocalizations.add),
          ),
        ),
        SizedBox(width: 8),
      ],
      body: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: EdgeInsets.symmetric(vertical: 16),
        itemBuilder: (context, index) {
          final proxyGroup = proxyGroups[index];
          return _buildItem(
            context: context,
            proxyGroup: proxyGroup,
            total: proxyGroups.length,
            index: index,
            onPressed: () {
              _handleEditProxyGroup(context, proxyGroup, index);
            },
          );
        },
        itemCount: proxyGroups.length,
        onReorder: (oldIndex, newIndex) {
          _handleReorder(ref, profileId, oldIndex, newIndex);
        },
      ),
    );
  }
}

class EditProxyGroupNestedSheet extends StatelessWidget {
  const EditProxyGroupNestedSheet({super.key});

  Future<void> _handleClose(
    BuildContext context,
    NavigatorState? navigatorState,
  ) async {
    if (navigatorState != null && navigatorState.canPop()) {
      final res = await globalState.showMessage(
        message: TextSpan(text: '确定要退出当前窗口吗?'),
      );
      if (res != true) {
        return;
      }
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handlePop(
    BuildContext context,
    NavigatorState? navigatorState,
  ) async {
    if (navigatorState != null && navigatorState.canPop()) {
      navigatorState.pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<NavigatorState> nestedNavigatorKey = GlobalKey();
    final nestedNavigator = Navigator(
      key: nestedNavigatorKey,
      onGenerateInitialRoutes: (navigator, initialRoute) {
        return [
          PagedSheetRoute(
            builder: (context) {
              return _EditProxyGroupView();
            },
          ),
        ];
      },
    );
    final sheetProvider = SheetProvider.of(context);
    return CommonPopScope(
      onPop: (_) async {
        _handlePop(context, nestedNavigatorKey.currentState);
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
                  _handleClose(context, nestedNavigatorKey.currentState);
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

class _EditProxyGroupView extends ConsumerStatefulWidget {
  const _EditProxyGroupView();

  @override
  ConsumerState createState() => _EditProxyGroupViewState();
}

class _EditProxyGroupViewState extends ConsumerState<_EditProxyGroupView> {
  Future<void> _showTypeOptions(GroupType type) async {
    final value = await globalState.showCommonDialog<GroupType>(
      child: OptionsDialog<GroupType>(
        title: '类型',
        options: GroupType.values,
        textBuilder: (item) => item.name,
        value: type,
      ),
    );
    if (value == null) {
      return;
    }
    ref
        .read(proxyGroupProvider.notifier)
        .update((state) => state.copyWith(type: value));
  }

  Future<void> _showIconEdit(String? icon) async {
    final value = await globalState.showCommonDialog<String>(
      child: IconEditDialog(icon),
    );
    if (value == null) {
      return;
    }
    ref
        .read(proxyGroupProvider.notifier)
        .update((state) => state.copyWith(icon: value));
  }

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

  void _handleToProxiesView() {
    Navigator.of(
      context,
    ).push(PagedSheetRoute(builder: (context) => EditProxiesView()));
  }

  void _handleToProvidersView() {}

  Widget _buildProvidersItem(bool includeAllProviders, List<String> use) {
    return _buildItem(
      title: Text('选择代理集'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          !includeAllProviders
              ? Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(
                    constraints: BoxConstraints(minWidth: 32),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: Text(
                        textAlign: TextAlign.center,
                        '${use.length}',
                        style: context.textTheme.bodySmall,
                      ),
                    ),
                  ),
                )
              : Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Colors.greenAccent.shade200,
                ),
          Icon(Icons.arrow_forward_ios),
        ],
      ),
      onPressed: _handleToProvidersView,
    );
  }

  Widget _buildFilterItem(String? filter) {
    return _buildItem(
      title: Text('节点过滤器'),
      trailing: TextFormField(
        textAlign: TextAlign.end,
        initialValue: filter,
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(filter: value));
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: '可选',
        ),
      ),
    );
  }

  Widget _buildMaxFailedTimesItem(int? maxFailedTimes) {
    return _buildItem(
      title: Text('最大失败次数'),
      trailing: TextFormField(
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.end,
        initialValue: maxFailedTimes?.toString(),
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update(
                (state) => state.copyWith(maxFailedTimes: int.tryParse(value)),
              );
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: '可选',
        ),
      ),
    );
  }

  Widget _buildUrlItem(String? url) {
    return _buildItem(
      title: Text('测试链接'),
      trailing: TextFormField(
        keyboardType: TextInputType.url,
        textAlign: TextAlign.end,
        initialValue: url,
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(url: value));
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: '可选',
        ),
      ),
    );
  }

  Widget _buildIntervalItem(int? interval) {
    return _buildItem(
      title: Text('测试间隔'),
      trailing: TextFormField(
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.end,
        initialValue: interval?.toString(),
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(interval: int.tryParse(value)));
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: '可选',
        ),
      ),
    );
  }

  Widget _buildExcludeFilterItem(String? excludeFilter) {
    return _buildItem(
      title: Text('排除节点过滤器'),
      trailing: TextFormField(
        textAlign: TextAlign.end,
        initialValue: excludeFilter,
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(excludeFilter: value));
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: '可选',
        ),
      ),
    );
  }

  Widget _buildExcludeTypeItem(String? type) {
    return _buildItem(
      title: Text('排除类型'),
      trailing: TextFormField(
        textAlign: TextAlign.end,
        initialValue: type,
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(excludeType: value));
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: '可选',
        ),
      ),
    );
  }

  Widget _buildExpectedStatusItem(String? expectedStatus) {
    return _buildItem(
      title: Text('预期状态'),
      trailing: TextFormField(
        textAlign: TextAlign.end,
        initialValue: expectedStatus,
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(expectedStatus: value));
        },
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: '可选',
        ),
      ),
    );
  }

  Widget _buildProxiesItem(bool includeAllProxies, List<String> proxies) {
    return _buildItem(
      title: Text('选择代理'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          !includeAllProxies
              ? Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(
                    constraints: BoxConstraints(minWidth: 32),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: Text(
                        textAlign: TextAlign.center,
                        '${proxies.length}',
                        style: context.textTheme.bodySmall,
                      ),
                    ),
                  ),
                )
              : Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Colors.greenAccent.shade200,
                ),
          Icon(Icons.arrow_forward_ios),
        ],
      ),
      onPressed: _handleToProxiesView,
    );
  }

  Widget _buildTypeItem(GroupType type) {
    return _buildItem(
      title: Text('类型'),
      onPressed: () {
        _showTypeOptions(type);
      },
      trailing: Text(type.name),
    );
  }

  Widget _buildIconItem(String? icon) {
    return _buildItem(
      title: Text('图标'),
      onPressed: () {
        _showIconEdit(icon);
      },
      trailing: TooltipText(
        text: Text(
          icon ?? '可选',
          maxLines: 1,
          style: context.textTheme.bodyLarge?.copyWith(
            color: icon == null ? context.colorScheme.onSurfaceVariant : null,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildNameItem(String name) {
    return _buildItem(
      title: Text('名称'),
      trailing: TextFormField(
        initialValue: name,
        onChanged: (value) {
          ref
              .read(proxyGroupProvider.notifier)
              .update((state) => state.copyWith(name: value));
        },
        textAlign: TextAlign.end,
        decoration: InputDecoration.collapsed(
          border: NoInputBorder(),
          hintText: '输入策略组名称',
        ),
      ),
    );
  }

  Widget _buildHiddenItem(bool? hidden) {
    void handleChangeHidden() {
      ref
          .read(proxyGroupProvider.notifier)
          .update((state) => state.copyWith(hidden: !(hidden ?? false)));
    }

    return _buildItem(
      title: Text('从列表中隐藏'),
      onPressed: handleChangeHidden,
      trailing: Switch(
        value: hidden ?? false,
        onChanged: (_) {
          handleChangeHidden();
        },
      ),
    );
  }

  Widget _buildLazyItem(bool? lazy) {
    void handleChangeLazy() {
      ref
          .read(proxyGroupProvider.notifier)
          .update((state) => state.copyWith(lazy: !(lazy ?? false)));
    }

    return _buildItem(
      title: Text('使用时测试'),
      onPressed: handleChangeLazy,
      trailing: Switch(
        value: lazy ?? false,
        onChanged: (_) {
          handleChangeLazy();
        },
      ),
    );
  }

  Widget _buildDisableUDPItem(bool? disableUDP) {
    void handleChangeDisableUDP() {
      ref
          .read(proxyGroupProvider.notifier)
          .update(
            (state) => state.copyWith(disableUDP: !(disableUDP ?? false)),
          );
    }

    return _buildItem(
      title: Text('禁用UDP'),
      onPressed: handleChangeDisableUDP,
      trailing: Switch(
        value: disableUDP ?? false,
        onChanged: (_) {
          handleChangeDisableUDP();
        },
      ),
    );
  }

  void _handleDelete(int profileId, String name) {
    ref.read(proxyGroupsProvider(profileId).notifier).del(name);
    context.safePop();
  }

  void _handleSave(int profileId, ProxyGroup proxyGroup) {
    ref.read(proxyGroupsProvider(profileId).notifier).put(proxyGroup);
    context.safePop();
  }

  @override
  Widget build(BuildContext context) {
    final isBottomSheet =
        SheetProvider.of(context)?.type == SheetType.bottomSheet;
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final proxyGroup = ref.watch(proxyGroupProvider);
    return AdaptiveSheetScaffold(
      sheetTransparentToolBar: true,
      actions: [
        IconButtonData(
          icon: Icons.check,
          onPressed: () {
            _handleSave(profileId, proxyGroup);
          },
        ),
      ],
      body: SizedBox(
        height: isBottomSheet
            ? appController.viewSize.height * 0.65
            : double.maxFinite,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(bottom: 20, top: context.sheetTopPadding),
          children: [
            generateSectionV3(
              title: '通用',
              items: [
                _buildNameItem(proxyGroup.name),
                _buildTypeItem(proxyGroup.type),
                _buildIconItem(proxyGroup.icon),
                _buildHiddenItem(proxyGroup.hidden),
                _buildDisableUDPItem(proxyGroup.disableUDP),
              ],
            ),
            generateSectionV3(
              title: '节点',
              items: [
                _buildProxiesItem(
                  proxyGroup.includeAllProxies ?? false,
                  proxyGroup.proxies ?? [],
                ),
                _buildProvidersItem(
                  proxyGroup.includeAllProviders ?? false,
                  proxyGroup.use ?? [],
                ),
                _buildFilterItem(proxyGroup.filter),
                _buildExcludeFilterItem(proxyGroup.excludeFilter),
                _buildExcludeTypeItem(proxyGroup.excludeType),
                _buildExpectedStatusItem(proxyGroup.expectedStatus),
              ],
            ),
            generateSectionV3(
              title: '其他',
              items: [
                _buildUrlItem(proxyGroup.url),
                _buildMaxFailedTimesItem(proxyGroup.maxFailedTimes),
                _buildLazyItem(proxyGroup.lazy),
                _buildIntervalItem(proxyGroup.interval),
              ],
            ),
            generateSectionV3(
              title: '操作',
              items: [
                _buildItem(
                  title: Text(
                    '删除',
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: context.colorScheme.error,
                    ),
                  ),
                  onPressed: () {
                    _handleDelete(profileId, proxyGroup.name);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      title: '编辑策略组',
    );
  }
}
