import 'package:flutter/material.dart';

Future<String?> askText(
  BuildContext context,
  String title, {
  String hint = 'Nhập nội dung cụ thể',
  bool numeric = false,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 17)),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: numeric ? TextInputType.number : TextInputType.multiline,
        maxLines: numeric ? 1 : 3,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Quay lại'),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  );
  // The dialog route can keep the text field alive during its closing animation.
  Future<void>.delayed(const Duration(milliseconds: 300), controller.dispose);
  return result;
}

Future<bool?> confirmRemoval(BuildContext context, String title) =>
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
