import 'package:flutter/material.dart';

/// Whether the pickers take the whole screen: shorter than Material's
/// compact height (480 dp), a phone in landscape. A fixed-size dialog
/// there leaves its list no room once the keyboard is up, so the
/// pickers go full screen and do not open the keyboard by themselves.
bool isShortScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 480;

/// A picker as a full-screen dialog, for [isShortScreen]: a close button
/// (cancel), [title] and the picker's [control] (a search field or a
/// dropdown) side by side in the bar, [actions] at its end, [body]
/// below.
class FullScreenPicker extends StatelessWidget {
  const FullScreenPicker({
    super.key,
    required this.title,
    required this.body,
    this.control,
    this.actions = const [],
  });

  final String title;
  final Widget? control;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final control = this.control;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: Row(
            children: [
              Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
              if (control != null) ...[
                const SizedBox(width: 16),
                Expanded(flex: 2, child: control),
              ],
            ],
          ),
          actions: [...actions, const SizedBox(width: 8)],
        ),
        body: body,
      ),
    );
  }
}
