import 'package:flutter/material.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';

class RideServicePicker extends StatelessWidget {
  final String selected;
  final bool enabled;
  final ValueChanged<String> onSelected;
  const RideServicePicker({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (code, asset, label, seats) in [
            ('BIKE', 'bike', 'Xe máy', '1 hành khách'),
            ('CAR_4', 'car', 'Ô tô 4 chỗ', 'Tối đa 4 khách'),
            ('CAR_7', 'suv', 'Ô tô 7 chỗ', 'Tối đa 7 khách'),
          ])
            SizedBox(
              width: largeText
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 20) / 3,
              child: Semantics(
                button: true,
                selected: selected == code,
                enabled: enabled,
                label: serviceLabel(code),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: selected == code
                        ? const Color(0xffeaf6ef)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected == code
                          ? grapGreen
                          : const Color(0xffe7ede9),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: enabled ? () => onSelected(code) : null,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                        child: largeText
                            ? Row(
                                children: [
                                  Image.asset(
                                    'assets/illustrations/ride_$asset.png',
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.contain,
                                    cacheWidth: 240,
                                    excludeFromSemantics: true,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          label,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          seats,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: grapMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selected == code)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 20,
                                      color: grapGreen,
                                    ),
                                ],
                              )
                            : Column(
                                children: [
                                  SizedBox(
                                    height: 78,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Image.asset(
                                            'assets/illustrations/ride_$asset.png',
                                            fit: BoxFit.contain,
                                            cacheWidth: 360,
                                            excludeFromSemantics: true,
                                          ),
                                        ),
                                        if (selected == code)
                                          const Positioned(
                                            top: 0,
                                            right: 0,
                                            child: Icon(
                                              Icons.check_circle_rounded,
                                              size: 17,
                                              color: grapGreen,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    code == 'BIKE'
                                        ? 'Linh hoạt'
                                        : code == 'CAR_4'
                                        ? 'Thoải mái'
                                        : 'Rộng rãi',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: grapMuted,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
