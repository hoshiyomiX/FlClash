part of 'overwrite.dart';

class _CustomRulesView extends ConsumerStatefulWidget {
  final int profileId;

  const _CustomRulesView(this.profileId);

  @override
  ConsumerState createState() => _CustomRulesViewState();
}

class _CustomRulesViewState extends ConsumerState<_CustomRulesView>
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
