{ ... }:

{
  security.rtkit.enable = true;
  services.pulseaudio.enable = false;

  # DaVinci Resolve dependency (discovered 2026-11-08): Resolve's Fairlight
  # audio engine loops forever re-enumerating devices during "New Project"
  # (GUI freezes, ~46% CPU, no crash) unless it finds a card exposing full
  # I/O channel maps. The onboard ALC1220 (alsa_card.pci-0000_7a_00.6) must
  # run PipeWire's "pro-audio" profile for Resolve to work. This is runtime
  # state, persisted by WirePlumber in
  # ~/.local/state/wireplumber/default-profile — it survives reboots. If it
  # is ever lost (state wipe/fresh install), re-apply:
  #   nix shell nixpkgs#pulseaudio -c pactl set-card-profile alsa_card.pci-0000_7a_00.6 pro-audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    
    wireplumber.extraConfig.bluetoothEnhancements = {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        # NOTE: do NOT override "bluez5.roles" here. A previous roles list
        # (hsp/hfp only) dropped a2dp_sink/a2dp_src, so WirePlumber registered
        # zero A2DP codecs ("No available A2DP codecs to register on adapter")
        # and every BT-speaker pair/connect failed at BlueZ with
        # "a2dp-sink profile connect failed: Protocol not available".
        # The default role set (all of hsp/hfp + a2dp) is what we want.
      };
    };
  };
}
