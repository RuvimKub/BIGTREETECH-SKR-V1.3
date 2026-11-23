# Handoff: install F3D Quick Look on the user's Mac

## Goal
User (Russian-speaking, short on time) wants Finder thumbnails + Space-bar (Quick Look)
preview for Fusion 360 `.f3d` files on macOS. Hundreds of old files exist; they must NOT
need re-saving. Reply to the user in Russian, briefly.

## Already established
- STEP/IGES/3MF: user bought **Unfold** (Mac App Store) -> works, thumbnails and Space-preview confirmed. Nothing to do.
- `.f3d` is a ZIP. It contains `FusionAssetName[Active]/Previews/small.png` (256x256 PNG,
  saved by Fusion on every save, so old files have it too). Geometry is in closed
  Autodesk `.smb/.smbh` blobs -> no 3D preview possible; static image only.
- Unfold does not handle `.f3d`.
- Therefore a custom Quick Look extension pair (thumbnail + preview) was written. It
  extracts that PNG. Code is in this folder (`F3DQuickLook/`), branch
  `claude/eager-gauss-53u0ka`. It was written on Linux and **never compiled or run**,
  so expect to fix small compile/signing/registration errors.

## What to do (on the Mac)
1. Get the repo: `RuvimKub/BIGTREETECH-SKR-V1.3`, branch `claude/eager-gauss-53u0ka`
   (the project is unrelated to the repo's 3D-printer firmware; only `F3DQuickLook/` matters).
2. Ensure Xcode Command Line Tools: `xcode-select --install` (check `swiftc --version`).
3. Find a sample `.f3d` on the Mac (ask the user where, or `mdfind -name .f3d`), then:
   `cd F3DQuickLook && chmod +x build.sh && ./build.sh /path/to/sample.f3d`
   (build.sh compiles app + 2 appex with swiftc, ad-hoc signs with sandbox entitlements,
   installs to ~/Applications, registers via lsregister/pluginkit, resets qlmanage, opens the app.)
4. Fix any build errors (likely spots: appex entry point flags in `build_ext`, framework
   names, QLPreviewReply API usage in `Preview/PreviewProvider.swift`).
5. User must enable **F3DThumbnail** and **F3DPreview** in System Settings > General >
   Login Items & Extensions > Quick Look (can't be scripted reliably; tell the user), then `killall Finder`.
6. Verify: `mdls -name kMDItemContentType sample.f3d`; `qlmanage -t -s 256 -o /tmp sample.f3d`;
   `qlmanage -p sample.f3d`; `pluginkit -mAvvv | grep -i f3d`.
   If the file's UTI is `dyn.*` or differs from what build.sh added, re-run build.sh with the sample.
7. If Unfold or another extension claims `.f3d`, disable it for that type.
8. Commit any fixes to the same branch and push. Do not open a PR unless asked.

## Known limits to tell the user
Static 256x256 image (it may show Fusion's purple selection highlight if that was
selected when saved). Files from very old Fusion versions might lack `Previews/`.
