{ config, pkgs, lib, ... }:

let
  cfg = config.hardware.nvidia.prime;
in
{
  options.hardware.nvidia.prime.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable NVIDIA PRIME offload for hybrid graphics (laptop with Intel+NVIDIA)";
  };

  config = {
  # NVIDIA GPU support module
  # Provides proprietary driver, CUDA support, and Wayland compatibility

  # Enable NVIDIA proprietary drivers
  services.xserver.videoDrivers = [ "nvidia" ];

  # Hardware acceleration support
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # Support for 32-bit applications

    # Include NVIDIA libraries for Vulkan support
    extraPackages = with pkgs; [
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  # NVIDIA-specific hardware configuration
  hardware.nvidia = {
    # Enable kernel modesetting (required for Wayland)
    modesetting.enable = true;

    # Power management for laptops
    powerManagement.enable = true;
    powerManagement.finegrained = false;  # Use full GPU power management

    # Use stable driver branch
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Open source kernel modules (set to false for proprietary)
    open = false;

    # Enable nvidia-settings GUI tool
    nvidiaSettings = true;

    # PRIME configuration for hybrid graphics (laptop)
    prime = lib.mkIf cfg.enable {
      offload = {
        enable = true;
        enableOffloadCmd = true;  # Provides `nvidia-offload` command
      };
    };
  };

  # Environment variables for better application compatibility
  environment.sessionVariables = {
    # Force GBM backend for better Wayland compatibility
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Enable GPU acceleration in Firefox/Electron apps
    MOZ_ENABLE_WAYLAND = "1";

    # Vulkan ICD
    VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
  };

  # Ensure kernel has necessary modules
  boot.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  # Load NVIDIA modules early in boot
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_drm" ];

  # Preserve video memory after suspend (helps with resume issues)
  boot.kernelParams = [ "nvidia.NVreg_PreserveVideoMemoryAllocations=1" ];

  # Enable systemd services for NVIDIA
  services.udev.extraRules = ''
    # Load NVIDIA kernel modules and create device nodes
    ACTION=="add", DEVPATH=="/bus/pci/drivers/nvidia", RUN+="${pkgs.kmod}/bin/modprobe nvidia-uvm"
  '';
  };
}
