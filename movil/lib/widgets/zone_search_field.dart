import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';

/// Campo de búsqueda de colonia o ubicación.
class ZoneSearchField extends StatefulWidget {
  const ZoneSearchField({super.key, required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  State<ZoneSearchField> createState() => _ZoneSearchFieldState();
}

class _ZoneSearchFieldState extends State<ZoneSearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSubmitted,
              style: const TextStyle(color: AppColors.darkInk, fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: AppStrings.searchHint,
                hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
