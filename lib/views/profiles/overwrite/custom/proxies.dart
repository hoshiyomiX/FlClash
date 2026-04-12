import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart' hide FileInfo;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class EditProxiesView extends ConsumerStatefulWidget {
  const EditProxiesView({super.key});

  @override
  ConsumerState<EditProxiesView> createState() => _EditProxiesViewState();
}

class _EditProxiesViewState extends ConsumerState<EditProxiesView>
    with UniqueKeyStateMixin {
  @override
  void initState() {
    super.initState();
    ref.listenManual(itemsProvider(key), (prev, next) {
      if (!SetEquality().equals(prev, next)) {
        _handleRealRemove();
      }
    });
  }

  void _handleToAddProxiesView() {
    Navigator.of(
      context,
    ).push(PagedSheetRoute(builder: (context) => _AddProxiesView()));
  }

  void _handleRemove(String proxyName) {
    ref.read(itemsProvider(key).notifier).update((state) {
      final newSet = Set.from(state);
      newSet.add(proxyName);
      return newSet;
    });
  }

  void _handleRealRemove() {
    debouncer.call(
      'EditProxiesViewState_handleRealRemove',
      () {
        if (!ref.context.mounted) {
          return;
        }
        final dismissItems = ref.read(itemsProvider(key));
        ref.read(proxyGroupProvider.notifier).update((state) {
          final newProxies = List<String>.from(state.proxies ?? []);
          newProxies.removeWhere((state) => dismissItems.contains(state));
          return state.copyWith(proxies: newProxies);
        });
        ref.read(itemsProvider(key).notifier).update((state) => <dynamic>{});
      },
      duration: Duration(milliseconds: 450),
    );
  }

  Widget _buildItem({
    required String proxyName,
    required String? proxyType,
    required int index,
    required int length,
    required ItemPosition position,
    required bool dismiss,
  }) {
    return ExternalDismissible(
      dismiss: dismiss,
      key: ValueKey(proxyName),
      onDismissed: _handleRealRemove,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ItemPositionProvider(
          position: position,
          child: DecorationListItem(
            minVerticalPadding: 8,
            title: Text(proxyName),
            subtitle: Text(proxyType ?? proxyName.toLowerCase()),
            contentPadding: EdgeInsets.only(left: 16, right: 8),
            leading: CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                onPressed: () {
                  _handleRemove(proxyName);
                },
                icon: Icon(Icons.remove, size: 18),
                padding: EdgeInsets.zero,
              ),
            ),
            trailing: ReorderableDelayedDragStartListener(
              index: index,
              child: Container(
                color: Colors.transparent,
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    ref.read(proxyGroupProvider.notifier).update((state) {
      final nextItems = List<String>.from(state.proxies ?? []);
      final item = nextItems.removeAt(oldIndex);
      nextItems.insert(newIndex, item);
      return state.copyWith(proxies: nextItems);
    });
  }

  void _handleChangeIncludeAllProxies() {
    ref
        .read(proxyGroupProvider.notifier)
        .update(
          (state) => state.copyWith(
            includeAllProxies: !(state.includeAllProxies ?? false),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final vm2 = ref.watch(
      proxyGroupProvider.select(
        (state) => VM2(state.includeAllProxies ?? false, state.proxies ?? []),
      ),
    );
    final dismissItems = ref.watch(itemsProvider(key));
    final includeAllProxies = vm2.a;
    final proxyNames = vm2.b;
    final proxyTypeMap =
        ref.watch(
          clashConfigProvider(
            profileId,
          ).select((state) => state.value?.proxyTypeMap),
        ) ??
        {};
    final isBottomSheet =
        SheetProvider.of(context)?.type == SheetType.bottomSheet;
    return SizedBox(
      height: isBottomSheet
          ? appController.viewSize.height * 0.85
          : double.maxFinite,
      child: AdaptiveSheetScaffold(
        title: '编辑代理',
        sheetTransparentToolBar: true,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: context.sheetTopPadding + 8),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: CommonCard(
                  radius: 20,
                  type: CommonCardType.filled,
                  child: ListItem.switchItem(
                    minTileHeight: 54,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('包含所有代理'),
                        CommonMinIconButtonTheme(
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              globalState.showMessage(
                                title: appLocalizations.tip,
                                message: TextSpan(
                                  text: '引入不包含策略组的所有代理，可在下方额外添加策略组',
                                ),
                                cancelable: false,
                              );
                            },
                            icon: Icon(
                              size: 16.ap,
                              Icons.info_outline,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    delegate: SwitchDelegate(
                      value: includeAllProxies,
                      onChanged: (_) {
                        _handleChangeIncludeAllProxies();
                      },
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: InfoHeader(
                  info: Info(label: '节点'),
                  actions: [
                    CommonMinFilledButtonTheme(
                      child: FilledButton.tonal(
                        onPressed: _handleToAddProxiesView,
                        child: Text('添加'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (proxyNames.isNotEmpty)
              SliverReorderableList(
                itemBuilder: (_, index) {
                  final proxyName = proxyNames[index];
                  final position = ItemPosition.calculateVisualPosition(
                    index,
                    proxyNames,
                    dismissItems,
                  );
                  return _buildItem(
                    position: position,
                    dismiss: dismissItems.contains(proxyName),
                    proxyName: proxyName,
                    proxyType: proxyTypeMap[proxyName],
                    index: index,
                    length: proxyNames.length,
                  );
                },
                itemCount: proxyNames.length,
                onReorder: (int oldIndex, int newIndex) {
                  _handleReorder(oldIndex, newIndex);
                },
              )
            else
              SliverFillRemaining(child: NullStatus(label: '代理为空')),
            SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

class _AddProxiesView extends ConsumerStatefulWidget {
  const _AddProxiesView();

  @override
  ConsumerState<_AddProxiesView> createState() => _AddProxiesViewState();
}

class _AddProxiesViewState extends ConsumerState<_AddProxiesView>
    with UniqueKeyStateMixin {
  @override
  void initState() {
    super.initState();
    ref.listenManual(itemsProvider('${key}_groups'), (prev, next) {
      if (!SetEquality().equals(prev, next)) {
        _handleRealAdd('groups');
      }
    });
    ref.listenManual(itemsProvider('${key}_proxies'), (prev, next) {
      if (!SetEquality().equals(prev, next)) {
        _handleRealAdd('proxies');
      }
    });
  }

  void _handleAdd(String name, String scene) {
    final realKey = '${key}_$scene';
    ref.read(itemsProvider(realKey).notifier).update((state) {
      final newSet = Set.from(state);
      newSet.add(name);
      return newSet;
    });
  }

  void _handleRealAdd(String scene) {
    debouncer.call(
      'AddProxiesViewState_handleRealAdd_$scene',
      () {
        if (!ref.context.mounted) {
          return;
        }
        final realKey = '${key}_$scene';
        final dismissItems = ref.read(itemsProvider(realKey));
        ref.read(proxyGroupProvider.notifier).update((state) {
          return state.copyWith(
            proxies: [...state.proxies ?? [], ...dismissItems],
          );
        });
        ref
            .read(itemsProvider(realKey).notifier)
            .update((state) => <dynamic>{});
      },
      duration: Duration(milliseconds: 350),
    );
  }

  Widget _buildItem({
    required String title,
    required String subtitle,
    required ItemPosition position,
    required bool dismiss,
    required VoidCallback onAdd,
  }) {
    return ExternalDismissible(
      effect: ExternalDismissibleEffect.resize,
      key: ValueKey(title),
      dismiss: dismiss,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ItemPositionProvider(
          position: position,
          child: DecorationListItem(
            minVerticalPadding: 8,
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                onPressed: onAdd,
                icon: Icon(Icons.add, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBottomSheet =
        SheetProvider.of(context)?.type == SheetType.bottomSheet;
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final dismissGroups = ref.watch(itemsProvider('${key}_groups'));
    final dismissProxies = ref.watch(itemsProvider('${key}_proxies'));
    final allProxiesAndProxyGroups = ref.watch(
      clashConfigProvider(profileId).select(
        (state) =>
            VM2(state.value?.proxies ?? [], state.value?.proxyGroups ?? []),
      ),
    );
    final allProxies = allProxiesAndProxyGroups.a;
    final allProxyGroups = allProxiesAndProxyGroups.b;
    final excludeProxyNames = ref.watch(
      proxyGroupProvider.select((state) {
        return [...?state.proxies, state.name];
      }),
    );
    final proxyGroups = allProxyGroups
        .where((item) => !excludeProxyNames.contains(item.name))
        .toList();
    final proxies = allProxies
        .where((item) => !excludeProxyNames.contains(item.name))
        .toList();
    final groupNames = proxyGroups.map((item) => item.name).toList();
    final proxyNames = proxies.map((item) => item.name).toList();
    return SizedBox(
      height: isBottomSheet
          ? appController.viewSize.height * 0.80
          : double.maxFinite,
      child: AdaptiveSheetScaffold(
        sheetTransparentToolBar: true,
        title: '添加代理',
        body: proxies.isEmpty && proxyGroups.isEmpty
            ? NullStatus(label: appLocalizations.noData)
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: context.sheetTopPadding),
                  ),
                  if (proxyGroups.isNotEmpty) ...[
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: InfoHeader(info: Info(label: '策略组')),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((_, index) {
                        final proxyGroup = proxyGroups[index];
                        final position = ItemPosition.calculateVisualPosition(
                          index,
                          groupNames,
                          dismissGroups,
                        );
                        return _buildItem(
                          title: proxyGroup.name,
                          subtitle: proxyGroup.type.value,
                          position: position,
                          dismiss: dismissGroups.contains(proxyGroup.name),
                          onAdd: () {
                            _handleAdd(proxyGroup.name, 'groups');
                          },
                        );
                      }, childCount: proxyGroups.length),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 8)),
                  ],
                  if (proxies.isNotEmpty) ...[
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: InfoHeader(info: Info(label: '代理')),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((_, index) {
                        final proxy = proxies[index];
                        final position = ItemPosition.calculateVisualPosition(
                          index,
                          proxyNames,
                          dismissProxies,
                        );
                        return _buildItem(
                          title: proxy.name,
                          subtitle: proxy.type,
                          position: position,
                          dismiss: dismissProxies.contains(proxy.name),
                          onAdd: () {
                            _handleAdd(proxy.name, 'proxies');
                          },
                        );
                      }, childCount: proxies.length),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
