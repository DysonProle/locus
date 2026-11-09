{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.locus.server;
in
{
  # The clan server's services: the Urbit ship, the gateway and the desk
  # deploy. No disk layout here, so this also evaluates outside NixOS, under
  # system-manager on a plain Linux host. server.nix adds
  # the Disko/ZFS storage on top.
  imports = [ ./urbit.nix ];

  options.locus.server = {
    enable = lib.mkEnableOption "clan server (Disko ZFS, pier dataset, snapshots, Urbit unit)";

    zfs.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        The pier lives on a ZFS dataset: Disko formats diskDevice, the ship
        refuses to start off that dataset, and desk deploys snapshot it
        first. Set false on a host whose disk Locus does not own (such as
        a cloud VM): the pier is then a plain directory, with no snapshots.
      '';
    };

    poolName = lib.mkOption {
      type = lib.types.str;
      default = "rpool";
      description = "ZFS pool name. Pier dataset is \${poolName}/urbit/pier.";
    };

    pierMountpoint = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/urbit/pier";
      description = "Mountpoint for the Urbit pier dataset.";
    };

    gateway = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Host gateway next to the ship: serves the browser app, stores file and
          photo bytes (SHA-256 addressed), and proxies Eyre so the browser sees
          one origin. Byte requests are checked against the ship's login.
        '';
      };
      package = lib.mkOption {
        type = lib.types.package;
        description = "locus-gateway package (set by the flake module).";
      };
      webRoot = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Compiled browser app served under /app/. Null serves nothing there.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8090;
        description = "Gateway listen port (all interfaces).";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open the gateway port in the firewall.";
      };
      maxUploadMb = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2048;
        description = "Largest single upload accepted, in MiB.";
      };
    };

    desk = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Install the %locus desk on the ship, and update it when its source
          changes (`locus-desk.service`, after the ship starts). Each deploy
          snapshots the pier first. On a new ship it also suspends Tlon's
          %groups and clears its %notes and %contacts, which clash with ours.
        '';
      };
      source = lib.mkOption {
        type = lib.types.path;
        description = "Directory with desk/ and scripts/ (set by the flake module).";
      };
    };

    ui = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          The interface (ui/) and its host (`locus-ui.service`): serves the
          page, proxies %store with the ship's login, and runs the agent.
          The host has no login of its own, so whoever reaches its port
          acts as the ship's owner. Keep it on loopback, or behind
          something that authenticates.
        '';
      };
      package = lib.mkOption {
        type = lib.types.package;
        description = "locus-ui package (set by the flake module).";
      };
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address the host listens on. See the warning on enable.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 5180;
        description = "Host listen port.";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open the host port in the firewall. See the warning on enable.";
      };
      agent = {
        keyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/etc/locus-ui/model.env";
          description = ''
            A file holding `ANTHROPIC_API_KEY=...`, readable by root only.
            It is read as an environment file when the host starts, and is
            never copied into the Nix store. With it, the agent runs the
            `claude` command (see `claude`). Without it, the agent is a
            canned model that knows only the phrases the tests use.
          '';
        };
        model = lib.mkOption {
          type = lib.types.str;
          default = "claude-haiku-5-5";
          description = "The model the agent asks for, when it has a key.";
        };
        claude = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.package lib.types.str);
          default = [ ];
          example = lib.literalExpression ''[ "/usr/local" ]'';
          description = ''
            Where the `claude` command is: packages or prefixes (their `bin`
            is used) added to the host's PATH.
          '';
        };
      };
      seed = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Fill an empty %store with the Home layout and the object types
            the interface needs (`locus-ui-store.service`). A store that
            already has a home is left alone, and each start adds what
            newer versions of the interface expect.
          '';
        };
        samples = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Include the sample notes and people when seeding.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Bytes live under /var/lib/locus/files on the root dataset (snapshotted).
    # A dedicated dataset can come later; adding one to an existing pool needs
    # a manual `zfs create`, so it is not declared here.
    systemd.services.locus-gateway = lib.mkIf cfg.gateway.enable {
      description = "Locus gateway (browser app, file bytes, Eyre proxy)";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "urbit.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " (
          [
            "${cfg.gateway.package}/bin/locus-gateway"
            "--listen 0.0.0.0:${toString cfg.gateway.port}"
            "--eyre http://127.0.0.1:${toString cfg.urbit.httpPort}"
            "--data-dir /var/lib/locus/files"
            "--max-upload-mb ${toString cfg.gateway.maxUploadMb}"
          ]
          ++ lib.optional (cfg.gateway.webRoot != null) "--web-root ${cfg.gateway.webRoot}"
        );
        DynamicUser = true;
        StateDirectory = "locus/files";
        StateDirectoryMode = "0700";
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
        SystemCallArchitectures = "native";
      };
    };
    # Runs desk-deploy.sh from the store. The stamp skips a deploy when the
    # source has not changed since the last good one.
    systemd.services.locus-desk = lib.mkIf cfg.desk.enable {
      description = "Install or update the %locus desk on the ship";
      wantedBy = [ "multi-user.target" ];
      after = [ "urbit.service" ];
      requires = [ "urbit.service" ];
      path = [
        cfg.urbit.package
        pkgs.bash
        pkgs.coreutils
        pkgs.curl
        pkgs.gnugrep
        pkgs.netcat-openbsd
        pkgs.rsync
        pkgs.systemd
        pkgs.zfs
      ];
      environment = {
        EYRE_URL = "http://127.0.0.1:${toString cfg.urbit.httpPort}";
        URBIT_PIER = "${cfg.pierMountpoint}/${cfg.urbit.verePierName}";
        LOCUS_NEW_SHIP = "1";
      }
      // lib.optionalAttrs (!cfg.zfs.enable) { LOCUS_SNAPSHOT = "0"; };
      script = ''
        export PATH=/run/wrappers/bin:$PATH
        stamp=/var/lib/locus-desk/deployed
        if [ "$(cat "$stamp" 2>/dev/null)" = ${cfg.desk.source} ]; then
          echo "%locus desk is up to date (${cfg.desk.source})"
          exit 0
        fi
        ${cfg.desk.source}/scripts/desk-deploy.sh
        echo ${cfg.desk.source} > "$stamp"
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "locus-desk";
        # A first install compiles every agent; a new comet also syncs first.
        TimeoutStartSec = "2h";
      };
    };

    # The interface's host. Its +code file is written as root before each
    # start, readable only by the host's dynamic user.
    systemd.services.locus-ui = lib.mkIf cfg.ui.enable {
      description = "Locus interface and its host";
      wantedBy = [ "multi-user.target" ];
      after = [ "urbit.service" ] ++ lib.optional cfg.desk.enable "locus-desk.service";
      requires = [ "urbit.service" ];
      environment = {
        HOST = cfg.ui.listenAddress;
        PORT = toString cfg.ui.port;
        LOCUS_SHIP = "http://127.0.0.1:${toString cfg.urbit.httpPort}";
        LOCUS_CODE_FILE = "/run/locus-ui/code";
        LOCUS_MEDIA = "/var/lib/locus-ui";
      } // (if cfg.ui.agent.keyFile == null then {
        LOCUS_LLM = "stub";
      } else {
        LOCUS_LLM = "claude";
        LOCUS_MODEL = cfg.ui.agent.model;
      });
      path = cfg.ui.agent.claude;
      serviceConfig = {
        EnvironmentFile = lib.mkIf (cfg.ui.agent.keyFile != null) cfg.ui.agent.keyFile;
        ExecStartPre = "+${pkgs.writeShellScript "locus-ui-code" ''
          set -eu
          code=$(${cfg.urbit.codePackage}/bin/urbit-code)
          ${pkgs.coreutils}/bin/install -m 0400 -o "$(${pkgs.coreutils}/bin/stat -c %u /run/locus-ui)" \
            /dev/null /run/locus-ui/code
          printf '%s\n' "$code" > /run/locus-ui/code
        ''}";
        ExecStart = lib.getExe' cfg.ui.package "locus-ui-host";
        DynamicUser = true;
        StateDirectory = "locus-ui";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "locus-ui";
        RuntimeDirectoryMode = "0700";
        # Until the ship answers on conn.sock, urbit-code fails; retry.
        Restart = "on-failure";
        RestartSec = "10s";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
        SystemCallArchitectures = "native";
      };
    };
    # Seeds an empty store and upgrades an older one, through the host.
    systemd.services.locus-ui-store = lib.mkIf (cfg.ui.enable && cfg.ui.seed.enable) {
      description = "Seed or upgrade the store for the Locus interface";
      wantedBy = [ "multi-user.target" ];
      after = [ "locus-ui.service" ];
      requires = [ "locus-ui.service" ];
      path = [ pkgs.curl ];
      environment = {
        LOCUS_URL = "http://127.0.0.1:${toString cfg.ui.port}";
      }
      // lib.optionalAttrs (!cfg.ui.seed.samples) { LOCUS_REAL = "1"; };
      script = ''
        for _ in $(seq 1 150); do
          curl -fsS -o /dev/null --max-time 5 "$LOCUS_URL/store/~/v1/state" && break
          sleep 2
        done
        ${lib.getExe' cfg.ui.package "locus-ui-seed"}
        ${lib.getExe' cfg.ui.package "locus-ui-upgrade"}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        DynamicUser = true;
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.optional (cfg.gateway.enable && cfg.gateway.openFirewall) cfg.gateway.port
      ++ lib.optional (cfg.ui.enable && cfg.ui.openFirewall) cfg.ui.port;
  };
}
