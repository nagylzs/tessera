import 'package:flutter/material.dart';

/// A [MenuAnchor] that the system back (Android's back button or gesture,
/// the browser's back) closes while it is open, instead of the route under
/// it.
///
/// Flutter's menus close on Escape but not on back
/// (https://github.com/flutter/flutter/issues/80052): back goes to the
/// [Navigator], which pops the dialog, sheet or page the menu sits on —
/// and the menu with it. While open, this menu holds a [LocalHistoryEntry]
/// on its [ModalRoute], the way an open drawer does, so the first back
/// only removes the entry, which closes the menu.
///
/// A [PopScope] with `canPop: false` on the same route still claims that
/// back first (a [ModalRoute] asks its pop scopes before its local
/// history); such a route lets the pop through with `canPop:
/// ModalRoute.of(context)!.willHandlePopInternally`.
class BackClosingMenuAnchor extends StatefulWidget {
  const BackClosingMenuAnchor({
    super.key,
    required this.menuChildren,
    required this.builder,
  });

  /// [MenuAnchor.menuChildren].
  final List<Widget> menuChildren;

  /// [MenuAnchor.builder].
  final MenuAnchorChildBuilder builder;

  @override
  State<BackClosingMenuAnchor> createState() => _BackClosingMenuAnchorState();
}

class _BackClosingMenuAnchorState extends State<BackClosingMenuAnchor> {
  final _menu = MenuController();
  LocalHistoryEntry? _entry;

  void _opened() {
    if (_entry != null) return;
    final route = ModalRoute.of(context);
    if (route == null) return;
    final entry = LocalHistoryEntry(
      onRemove: () {
        // removed by a back: close the menu; removed by _closed: no-op
        _entry = null;
        if (_menu.isOpen) _menu.close();
      },
    );
    _entry = entry;
    route.addLocalHistoryEntry(entry);
  }

  void _closed() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
  }

  @override
  void dispose() {
    _closed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _menu,
    onOpen: _opened,
    onClose: _closed,
    menuChildren: widget.menuChildren,
    builder: widget.builder,
  );
}
