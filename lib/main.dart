import 'package:flutter/material.dart';

/// Entrypoint of the application.
void main() {
  runApp(const MyApp());
}

/// Enum representing the status of the dragged icon.
enum DragStatus { none, picked, dropped, cancelled }

/// Enum representing the status of a slot in the dock.
enum SlotStatus { none, empty, filled }

/// Class representing a slot in the dock.
class Slot {
  /// Status of the slot.
  SlotStatus status;

  /// Index of the slot.
  int index;

  /// Open slot positions associated with this slot.
  OpenSlot openSlot;

  /// Creates a [Slot] with a [status], [index], and [openSlot].
  Slot({
    required this.status,
    required this.index,
    required this.openSlot,
  });
}

/// Class representing the open slot positions (left and right) for a [Slot].
class OpenSlot {
  /// Global key for the left open slot.
  GlobalKey? left;

  /// Global key for the right open slot.
  GlobalKey? right;

  /// Creates an [OpenSlot] with optional [left] and [right] keys.
  OpenSlot({
    required this.left,
    required this.right,
  });
}

/// Global variables to track the drag-and-drop state.
int? dragStartIndex; // Index of the icon being dragged.
int? dragTargetIndex; // Index of the target slot being hovered over.
Offset? dragLocation; // Location of the dragged icon.
DragStatus dragStatus = DragStatus.none; // Current drag status.
bool dropped = false; // Whether the icon was successfully dropped.

/// List of icons in the dock.
final List<IconData> icons = [
  Icons.person,
  Icons.message,
  Icons.call,
  Icons.camera,
  Icons.photo,
];

/// List of slots, initialized with the icons.
List<Slot> slots = List.generate(
  icons.length,
  (index) => Slot(
    status: SlotStatus.filled,
    index: index,
    openSlot: OpenSlot(
      left: index == 0 ? GlobalKey() : null,
      right: GlobalKey(),
    ),
  ),
);

/// Main application widget.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: DockPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Page displaying the dock and drag-and-drop functionality.
class DockPage extends StatefulWidget {
  const DockPage({super.key});

  @override
  State<DockPage> createState() => _DockPageState();
}

class _DockPageState extends State<DockPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Dock<Slot>(
              items: slots,
              builder: (slot, index) {
                return Row(
                  children: [
                    if (slot.openSlot.left != null)
                      AnimatedContainer(
                        duration: dragStatus == DragStatus.dropped
                            ? Duration.zero
                            : const Duration(milliseconds: 100),
                        height: 48,
                        width: dragTargetIndex == index ? 64 : 8,
                        key: slot.openSlot.left,
                      ),
                    GestureDetector(
                      onVerticalDragStart: (details) {
                        setState(() {
                          dragStartIndex = index;
                          slots[index].status = SlotStatus.none;
                          dragStatus = DragStatus.picked;
                        });
                      },
                      onVerticalDragUpdate: (details) {
                        setState(() {
                          dragLocation = Offset(
                            details.globalPosition.dx - 32,
                            details.globalPosition.dy - 32,
                          );
                          dragTargetIndex = _detectHoveredSlot();
                        });
                      },
                      onVerticalDragEnd: (details) async {
                        await _handleDragEnd(context);
                      },
                      child: DockSlot(slot: slot),
                    ),
                    if (slot.openSlot.right != null &&
                        (dragStartIndex != index))
                      AnimatedContainer(
                        duration: dragStatus == DragStatus.dropped
                            ? Duration.zero
                            : const Duration(milliseconds: 100),
                        height: 48,
                        width: dragStartIndex != null
                            ? dragTargetIndex ==
                                    (dragStartIndex! < index
                                        ? index
                                        : index + 1)
                                ? 64
                                : 8
                            : 8,
                        key: slot.openSlot.right,
                      ),
                  ],
                );
              },
            ),
          ),
          if (dragStartIndex != null && dragLocation != null)
            AnimatedPositioned(
              left: dragLocation?.dx,
              top: dragLocation?.dy,
              duration: dragStatus != DragStatus.picked
                  ? const Duration(milliseconds: 300)
                  : const Duration(milliseconds: 100),
              child: Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.primaries[
                      icons[slots[dragStartIndex!].index].hashCode %
                          Colors.primaries.length],
                ),
                child: Center(
                  child: Icon(
                    icons[slots[dragStartIndex!].index],
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Refreshes the slot list and reassigns the keys for open slots.
  void _refreshSlots() {
    slots = List.generate(
      icons.length,
      (index) => Slot(
        status: slots[index].status,
        index: slots[index].index,
        openSlot: OpenSlot(
          left: index == 0 ? GlobalKey() : null,
          right: GlobalKey(),
        ),
      ),
    );
  }

  /// Handles the end of a drag operation.
  Future<void> _handleDragEnd(BuildContext context) async {
    if (dragTargetIndex != null) {
      setState(() {
        dragStatus = DragStatus.dropped;

        dragLocation = _getOriginalPosition(context, dragTargetIndex!);
      });

      await Future.delayed(const Duration(milliseconds: 200));

      setState(() {
        Slot startSlot = slots[dragStartIndex!];
        slots.removeAt(dragStartIndex!);
        slots.insert(dragTargetIndex!, startSlot);
        _refreshSlots();
        dragStartIndex = null;
        slots[dragTargetIndex!].status = SlotStatus.filled;
        dragTargetIndex = null;
        dragLocation = null;
      });
    } else {
      setState(() {
        dragStatus = DragStatus.cancelled;
        dragLocation = _getOriginalPosition(context, dragStartIndex!);
      });

      await Future.delayed(const Duration(milliseconds: 150));
      setState(() {
        slots[dragStartIndex!].status = SlotStatus.empty;
      });

      await Future.delayed(const Duration(milliseconds: 60));
      setState(() {
        slots[dragStartIndex!].status = SlotStatus.filled;
        dragStartIndex = null;
        dragLocation = null;
        dragTargetIndex = null;
      });
    }
  }

  /// Returns the original position of the dragged icon.
  Offset _getOriginalPosition(BuildContext context, int index) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    double left = ((width / 2) - 144) + (56 * index);
    double top = (height / 2) - 32;
    return Offset(left, top);
  }

  /// Detects which slot is being hovered.
  int? _detectHoveredSlot() {
    if (dragLocation == null) return null;

    final Rect draggedIconRect =
        Rect.fromLTWH(dragLocation!.dx, dragLocation!.dy, 48, 48);

    for (int i = 0; i < slots.length; i++) {
      GlobalKey? leftSlot = slots[i].openSlot.left;
      GlobalKey? rightSlot = slots[i].openSlot.right;

      if (leftSlot != null) {
        bool check = _isHovering(leftSlot, draggedIconRect);

        if (check) {
          return (dragStartIndex! < i) ? i - 1 : i;
        }
      }

      if (rightSlot != null) {
        bool check = _isHovering(rightSlot, draggedIconRect);

        if (check) {
          return (dragStartIndex! < i) ? i : i + 1;
        }
      }
    }
    return null;
  }

  /// Checks if the dragged icon overlaps with a given slot.
  bool _isHovering(GlobalKey key, Rect draggedRect) {
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;

    final Rect slotRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;

    return draggedRect.overlaps(slotRect);
  }
}

/// Widget representing a single slot in the dock.
class DockSlot extends StatelessWidget {
  /// Slot data to render.
  final Slot slot;

  const DockSlot({super.key, required this.slot});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: (dragStatus != DragStatus.picked &&
              dragStatus != DragStatus.cancelled)
          ? Duration.zero
          : const Duration(milliseconds: 100),
      width: slot.status == SlotStatus.none ? 0 : 48,
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: slot.status != SlotStatus.filled
            ? null
            : Colors.primaries[
                icons[slot.index].hashCode % Colors.primaries.length],
      ),
      child: slot.status == SlotStatus.filled
          ? Center(child: Icon(icons[slot.index], color: Colors.white))
          : null,
    );
  }
}

/// Reorderable dock containing items of type [T].
class Dock<T> extends StatelessWidget {
  /// List of items in the dock.
  final List<T> items;

  /// Function to build each item.
  final Widget Function(T, int index) builder;

  const Dock({super.key, this.items = const [], required this.builder});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black12,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            items.map((item) => builder(item, items.indexOf(item))).toList(),
      ),
    );
  }
}
