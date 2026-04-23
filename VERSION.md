# WorkPod Version History

## v0.1.0
- Initial implementation of window management.

## v0.1.1
- Added full-screen window support using `.optionAll`.
- Implemented basic noise filtering using `layer == 0`.
- Introduced unique ID suffix in display names.

## v0.1.2
- Added `alpha < 0.1` filtering to reduce ghost windows.
- Attempted AX title matching for custom window titles (e.g., Ghostty).

## v0.1.3
- **Fixed**: Window matching logic. Switched from title-based matching to **Bounds-based matching** (comparing CGRect), ensuring 100% accuracy when linking CG windows to AX elements.
- **Improved**: Window filtering. Added zero-size and extreme-size filtering to further eliminate ghost windows.
- **Fixed**: Title extraction for Ghostty and other modern apps by prioritizing `kAXTitleAttribute` after bounds matching.

## v0.1.4
|- **Fixed**: Window noise reduction. Added diagnostic logging and implemented deduplication for redundant windows from the same PID to solve the "multiple ghost windows for one terminal" issue.

## v0.1.5
|- **Fixed**: Activity Monitor redundancy. Enhanced deduplication with near-duplicate, center-point distance, and same-title overlap filters.
|- **Improved**: Dynamic overlap thresholding based on window size ratios to better distinguish between main windows and auxiliary overlays.

