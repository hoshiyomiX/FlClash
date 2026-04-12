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

class EditProxyProvidersView extends ConsumerStatefulWidget {
  const EditProxyProvidersView({super.key});

  @override
  ConsumerState<EditProxyProvidersView> createState() =>
      _EditProxyProvidersViewState();
}

class _EditProxyProvidersViewState extends ConsumerState<EditProxyProvidersView>
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

  void _handleToAddProxyProvidersView() {
    Navigator.of(
      context,
    ).push(PagedSheetRoute(builder: (context) => _AddProxyProvidersView()));
  }

  void _handleRemove(String providerName) {
    ref.read(itemsProvider(key).notifier).update((state) {
      final newSet = Set.from(state);
      newSet.add(providerName);
      return newSet;
    });
  }

  void _handleRealRemove() {
    debouncer.call(
      'EditProxyProvidersViewState_handleRealRemove',
      () {
        if (!ref.context.mounted) {
          return;
        }
        final dismissItems = ref.read(itemsProvider(key));
        ref.read(proxyGroupProvider.notifier).update((state) {
          final newProxyProviders = List<String>.from(state.use ?? []);
          newProxyProviders.removeWhere(
            (state) => dismissItems.contains(state),
          );
          return state.copyWith(use: newProxyProviders);
        });
        ref.read(itemsProvider(key).notifier).update((state) => <dynamic>{});
      },
      duration: Duration(milliseconds: 450),
    );
  }

  Widget _buildItem({
    required String providerName,
    required int index,
    required int length,
    required ItemPosition position,
    required bool dismiss,
  }) {
    return ExternalDismissible(
      dismiss: dismiss,
      key: ValueKey(providerName),
      onDismissed: _handleRealRemove,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ItemPositionProvider(
          position: position,
          child: DecorationListItem(
            minVerticalPadding: 8,
            title: Text(providerName),
            leading: CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                onPressed: () {
                  _handleRemove(providerName);
                },
                icon: Icon(Icons.remove, size: 18),
                padding: EdgeInsets.zero,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDelayedDragStartListener(
                  index: index,
                  child: Container(
                    color: Colors.transparent,
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
                SizedBox(width: 4),
              ],
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
      final nextItems = List<String>.from(state.use ?? []);
      final item = nextItems.removeAt(oldIndex);
      nextItems.insert(newIndex, item);
      return state.copyWith(use: nextItems);
    });
  }

  void _handleChangeIncludeAllProxyProviders() {
    ref
        .read(proxyGroupProvider.notifier)
        .update(
          (state) => state.copyWith(
            includeAllProviders: !(state.includeAllProviders ?? false),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final vm2 = ref.watch(
      proxyGroupProvider.select(
        (state) => VM2(state.includeAllProviders ?? false, state.use ?? []),
      ),
    );
    final dismissItems = ref.watch(itemsProvider(key));
    final includeAllProxyProviders = vm2.a;
    final proxyProviderNames = vm2.b;
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
                        Text('包含所有代理集'),
                        CommonMinIconButtonTheme(
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              globalState.showMessage(
                                title: appLocalizations.tip,
                                message: TextSpan(text: '开启后将覆盖引入的代理集'),
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
                      value: includeAllProxyProviders,
                      onChanged: (_) {
                        _handleChangeIncludeAllProxyProviders();
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
                  info: Info(label: '代理集'),
                  actions: [
                    CommonMinFilledButtonTheme(
                      child: FilledButton.tonal(
                        onPressed: _handleToAddProxyProvidersView,
                        child: Text('添加'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (proxyProviderNames.isNotEmpty)
              SliverReorderableList(
                itemBuilder: (_, index) {
                  final providerName = proxyProviderNames[index];
                  final position = ItemPosition.calculateVisualPosition(
                    index,
                    proxyProviderNames,
                    dismissItems,
                  );
                  return _buildItem(
                    position: position,
                    dismiss: dismissItems.contains(providerName),
                    providerName: providerName,
                    index: index,
                    length: proxyProviderNames.length,
                  );
                },
                itemCount: proxyProviderNames.length,
                onReorder: (int oldIndex, int newIndex) {
                  _handleReorder(oldIndex, newIndex);
                },
              )
            else
              SliverFillRemaining(child: NullStatus(label: '代理集为空')),
            SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

class _AddProxyProvidersView extends ConsumerStatefulWidget {
  const _AddProxyProvidersView();

  @override
  ConsumerState<_AddProxyProvidersView> createState() =>
      _AddProxyProvidersViewState();
}

class _AddProxyProvidersViewState extends ConsumerState<_AddProxyProvidersView>
    with UniqueKeyStateMixin {
  @override
  void initState() {
    super.initState();
    ref.listenManual(itemsProvider(key), (prev, next) {
      if (!SetEquality().equals(prev, next)) {
        _handleRealAdd();
      }
    });
  }

  void _handleAdd(String name) {
    ref.read(itemsProvider(key).notifier).update((state) {
      final newSet = Set.from(state);
      newSet.add(name);
      return newSet;
    });
  }

  void _handleRealAdd() {
    debouncer.call(
      'AddProxyProvidersViewState_handleRealAdd',
      () {
        if (!ref.context.mounted) {
          return;
        }
        final dismissItems = ref.read(itemsProvider(key));
        ref.read(proxyGroupProvider.notifier).update((state) {
          return state.copyWith(use: [...state.use ?? [], ...dismissItems]);
        });
        ref.read(itemsProvider(key).notifier).update((state) => <dynamic>{});
      },
      duration: Duration(milliseconds: 350),
    );
  }

  Widget _buildItem({
    required String title,
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
            trailing: CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                onPressed: onAdd,
                icon: Icon(Icons.add, size: 18),
                padding: EdgeInsets.zero,
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
    final dismissProxyProviders = ref.watch(itemsProvider(key));
    final allProxyProviders = ref.watch(
      clashConfigProvider(
        profileId,
      ).select((state) => state.value?.proxyProviders ?? []),
    );
    final excludeProxyProviderNames = ref.watch(
      proxyGroupProvider.select((state) {
        return [...?state.use];
      }),
    );
    final providerNames = allProxyProviders
        .where((item) => !excludeProxyProviderNames.contains(item))
        .toList();
    return SizedBox(
      height: isBottomSheet
          ? appController.viewSize.height * 0.80
          : double.maxFinite,
      child: AdaptiveSheetScaffold(
        sheetTransparentToolBar: true,
        title: '添加代理',
        body: providerNames.isEmpty
            ? NullStatus(label: appLocalizations.noData)
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: context.sheetTopPadding),
                  ),
                  if (providerNames.isNotEmpty) ...[
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: InfoHeader(info: Info(label: '代理')),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((_, index) {
                        final providerName = providerNames[index];
                        final position = ItemPosition.calculateVisualPosition(
                          index,
                          providerNames,
                          dismissProxyProviders,
                        );
                        return _buildItem(
                          title: providerName,
                          position: position,
                          dismiss: dismissProxyProviders.contains(providerName),
                          onAdd: () {
                            _handleAdd(providerName);
                          },
                        );
                      }, childCount: providerNames.length),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
