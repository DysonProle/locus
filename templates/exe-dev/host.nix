{ config, lib, ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";

  locus.server = {
    enable = true;
    # The VM's disk is not ours to format: the pier is a plain directory
    # under /var/lib/urbit/pier, with no snapshots.
    zfs.enable = false;
    # Eyre on loopback only. The gateway (port 8090, in exe.dev's proxied
    # range 3000-9999) is the one way in, and it proxies Eyre.
    urbit.httpIp = "127.0.0.1";
    urbit.httpPort = 8080;
  };

  # desk-deploy.sh runs `sudo -u urbit`. system-manager leaves sudo to the
  # host, so the unit needs /usr/bin on its PATH: last, so the pinned nc,
  # rsync and curl still win over the host's. Guarded so that turning the
  # desk off does not leave an empty locus-desk unit behind.
  systemd.services = lib.mkIf config.locus.server.desk.enable {
    locus-desk.path = lib.mkAfter [ "/usr" ];
  };
}
