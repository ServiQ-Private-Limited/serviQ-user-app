import 'package:flutter/material.dart';

import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/core/app_color.dart';

/// The square button that opens a screen's filter sheet.
///
/// It fills with the accent once something is applied, so a short list reads
/// as narrowed rather than as an empty area — which is the whole reason the
/// filter moved out of a chip rail and into a sheet: the chips said what was
/// on, and without them the icon has to.
class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.isFiltered,
    required this.onTap,
  });

  final bool isFiltered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.9,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isFiltered ? AppColor.discoveryAccent : AppColor.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFiltered
                ? AppColor.discoveryAccent
                : AppColor.discoveryBorder,
            width: 1.4,
          ),
        ),
        child: Icon(
          Icons.tune_rounded,
          size: 19,
          color: isFiltered ? AppColor.white : AppColor.discoveryTextSecondary,
        ),
      ),
    );
  }
}
