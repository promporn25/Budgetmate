# Transparent category artwork

Created with the built-in imagegen tool. App assets are in `assets/images/categories/`:

- `pastel_collection_00_transparent.png` through `pastel_collection_11_transparent.png`
- `pastel_extra_atlas_transparent.png`
- `pastel_atlas_transparent.png`

Original atlas files are retained. `PastelArtwork` uses the transparent variants; artwork numbers and cell order remain unchanged. The peach now uses its original atlas cell with the background removed. The standalone lipstick remains in use.

## Prompt for collection and extra atlases

Use case: background-extraction. Edit the supplied sprite atlas. Remove ONLY the white background and cast ground shadows around EVERY object, replacing with true transparent alpha. Preserve all 36 original illustrations exactly: appearance, colors, faces, fine details, size, pixel positions, original square canvas and exact 6-column by 6-row cell grid. Preserve white parts belonging to objects. No rearrangement, no redraw, no cropping or enlarging, no new objects. Output the entire same atlas as a transparent PNG, not a checkerboard.

For collection 11: This sheet contains only 14 objects in its first 14 cells. Keep all remaining 22 cells empty and transparent; do not fill them.

## Original atlas cleanup prompt

Use case: background-extraction. Clean up this existing partially transparent icon atlas: remove all remaining white background flecks, white halos, colored fringe artifacts and cast ground shadows outside the objects. True transparent alpha background. Preserve EVERY original object and all white surfaces of the objects, faces and colors. Preserve exact 1254x1254 square canvas and every object's exact position and size. This irregular grid has 8 icons in most rows and 9 in the fifth row; DO NOT regularize, rearrange or move anything. No redesign, additions or crop. Output entire PNG atlas with clean object cutouts.
