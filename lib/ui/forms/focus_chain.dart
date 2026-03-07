import 'package:flutter/material.dart';

class FocusChain {
  final List<FocusNode> nodes;
  final Map<FocusNode, VoidCallback> _listeners = {};

  FocusChain(this.nodes);

  void focusNext(BuildContext context, FocusNode current) {
    final index = nodes.indexOf(current);
    if (index == -1 || index >= nodes.length - 1) {
      FocusScope.of(context).unfocus();
      return;
    }
    final next = nodes[index + 1];
    FocusScope.of(context).requestFocus(next);
    _ensureVisible(next);
  }

  void focusDone(BuildContext context, VoidCallback onDone) {
    FocusScope.of(context).unfocus();
    onDone();
  }

  void enableAutoScroll() {
    for (final node in nodes) {
      if (_listeners.containsKey(node)) {
        continue;
      }
      void listener() {
        if (!node.hasFocus) {
          return;
        }
        _ensureVisible(node);
      }

      _listeners[node] = listener;
      node.addListener(listener);
    }
  }

  void _ensureVisible(FocusNode node) {
    final target = node.context;
    if (target == null) {
      return;
    }
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.25,
    );
  }

  void dispose() {
    for (final entry in _listeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _listeners.clear();
    for (final node in nodes) {
      node.dispose();
    }
  }
}
