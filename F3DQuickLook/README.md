# F3D Quick Look

Finder thumbnails and Space-bar preview for Fusion 360 `.f3d` files on macOS.

A `.f3d` is a ZIP archive. Fusion 360 stores a 256x256 render of the model in
`Previews/small.png` on every save. These two Quick Look extensions read that
image, so **existing files work without re-saving**. The preview is a static
image, not a rotatable 3D model (the geometry is in Autodesk's closed format).

## Install

1. Install Xcode Command Line Tools if needed: `xcode-select --install`
2. In Terminal:
   ```
   cd F3DQuickLook
   chmod +x build.sh
   ./build.sh /path/to/any-file.f3d
   ```
   (The sample path is optional but helps if Fusion 360 already defines the `.f3d` file type.)
3. The app opens once. Then go to
   *System Settings -> General -> Login Items & Extensions -> Quick Look*
   and enable **F3DThumbnail** and **F3DPreview**.
4. `killall Finder`

## Troubleshooting

- Check the file type of your files: `mdls -name kMDItemContentType file.f3d`.
  If it is a `dyn.…` value or something other than what the script detected,
  re-run `./build.sh file.f3d` so it is added to the supported types.
- Reset the cache: `qlmanage -r && qlmanage -r cache && killall Finder`
- Keep the app in `~/Applications`; the extensions live inside it.
- Test directly: `qlmanage -p file.f3d` and `qlmanage -t -s 256 -o /tmp file.f3d`
- If another Quick Look extension claims `.f3d` (Unfold, etc.), disable it for that type or reorder in the same settings pane.
