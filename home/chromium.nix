# =============================================================================
# chromium.nix — the browser as a Home Manager program (was a bare system
# package in modules/apps/desktop-apps.nix)
# =============================================================================
# WHY A HOME-MANAGER "PROGRAM" INSTEAD OF A PACKAGE:
#   programs.chromium installs the browser AND renders its launch flags into
#   the desktop entry, so every way you launch it (rofi, dock, `chromium`)
#   gets the same arguments. With a bare package, flags would need a wrapper
#   script or be forgotten.
#
# THE THREE FLAGS (each fixes one real problem on this NVIDIA + Wayland box):
#
#   password-store=gnome-libsecret
#       Save passwords in gnome-keyring (enabled in hosts/desktop/default.nix)
#       instead of Chromium's fallback, which stores them UNENCRYPTED in
#       ~/.config/chromium/.../Login Data.
#
#   VaapiVideoDecodeLinuxGL
#       Use VA-API for video decode. Combined with nvidia-vaapi-driver +
#       LIBVA_DRIVER_NAME=nvidia (modules/nvidiagpu-compute.nix) this routes
#       YouTube & co. through NVDEC on the RTX 5080 instead of the CPU.
#       Verify after switching: chrome://gpu → "Video Decode" should say
#       "Hardware accelerated".
#
#   ozone-platform-hint=auto
#       Prefer native Wayland over XWayland when the session is Wayland:
#       sharper rendering at fractional scales, no X11 round-trip. If some
#       site/app ever misbehaves, launch with
#       `chromium --ozone-platform=x11` to compare, and drop this flag.
# =============================================================================
{ pkgs, ... }:

{
  programs.chromium = {
    enable = true;
    package = pkgs.chromium;

    commandLineArgs = [
      "--password-store=gnome-libsecret"
      "--enable-features=VaapiVideoDecodeLinuxGL"
      "--ozone-platform-hint=auto"
    ];
  };
}
