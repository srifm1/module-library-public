# Network Specification / IP Registry
# Single source of truth for network topology, IP assignments, and DNS records.
# Consumed by host configs via module-library's lib.networkSpec output.
{
  domain = "example.net";

  # VLAN definitions
  vlans = {
    infra = {
      id = 10;
      subnet = "10.88.1.0/24";
      gateway = "10.88.1.1";
    };
    client-wifi-dhcp = {
      id = 11;
      subnet = "10.89.100.0/24";
      gateway = "10.89.100.1";
    };
    iot-wifi-dhcp = {
      id = 12;
      subnet = "10.89.110.0/24";
      gateway = "10.89.110.1";
    };
    cabled-dhcp = {
      id = 13;
      subnet = "10.89.50.0/24";
      gateway = "10.89.50.1";
    };
    cabled-iot-dhcp = {
      id = 14;
      subnet = "10.89.60.0/24";
      gateway = "10.89.60.1";
    };
    client-wifi-static = {
      id = 15;
      subnet = "10.88.100.0/24";
      gateway = "10.88.100.1";
    };
    iot-wifi-static = {
      id = 16;
      subnet = "10.88.110.0/24";
      gateway = "10.88.110.1";
    };
    cabled-static = {
      id = 17;
      subnet = "10.88.50.0/24";
      gateway = "10.88.50.1";
    };
    cabled-iot-static = {
      id = 18;
      subnet = "10.88.60.0/24";
      gateway = "10.88.60.1";
    };
    servers = {
      id = 19;
      subnet = "10.88.10.0/24";
      gateway = "10.88.10.1";
    };
    vms = {
      id = 20;
      subnet = "10.88.20.0/24";
      gateway = "10.88.20.1";
    };
  };

  # WireGuard VPN networks
  wireguard = {
    p2s = {
      network = "10.77.100.0/24";
      gateway = "10.77.100.1";
      port = 51820;
    };
    s2s = {
      network = "10.77.200.0/30";
      gateway = "10.77.200.1";
      port = 51821;
    };
  };

  # Host IP assignments
  # hostname -> { vlan-name = "ip"; ... }
  hosts = {
    router1 = {
      infra = "10.88.1.1";
      vms = "10.88.20.1";
      # Router is the gateway for all VLANs; IPs are the gateway addresses above
    };
    bmhost1 = {
      infra = "10.88.1.50";
    };
    services1 = {
      vms = "10.88.20.10";
      vms-vpn = "10.88.20.11";  # Secondary IP for VPN source routing
    };
    devdesktop1 = {
      cabled-static = "10.88.50.10";
    };
    devvm1 = {
      vms = "10.88.20.50";
    };
    # Access points
    ap1 = {
      infra = "10.88.1.100";
    };
    unifi = {
      infra = "10.88.1.11";  # UniFi controller (secondary IP on bmhost1)
    };
    nas = {
      servers = "10.88.10.10";
    };
  };

  # NFS server address (bmhost1 on infra VLAN)
  nfsServer = "10.88.1.50";

  # DNS records
  dns = {
    # Forward records: hostname -> IP
    records = {
      "bmhost1" = "10.88.1.50";
      "unifi" = "10.88.1.11";
      "ap1" = "10.88.1.100";
      "nas" = "10.88.10.10";
      "services" = "10.88.20.10";
      "router" = "10.88.20.1";
    };

    # Extra records (non-standard patterns)
    extraRecords = [
      ''"example.net. A 10.88.1.1"''
      ''"services.example.net. A 10.88.20.10"''
    ];

    # Subdomain redirect zones (wildcard-like)
    subdomainZones = [
      { zone = "services.example.net."; ip = "10.88.20.10"; }
    ];

    # Reverse DNS zones
    reverseZones = [
      "10.in-addr.arpa."
    ];
  };
}
