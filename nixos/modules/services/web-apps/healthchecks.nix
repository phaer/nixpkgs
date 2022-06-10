{ config, lib, pkgs, buildEnv, ... }:

with lib;

let
  cfg = config.services.healthchecks;
  pkg = pkgs.healthchecks;
  boolToPython = b: if b then "True" else "False";
  environment = {
    PYTHONPATH = pkg.pythonPath;
    STATIC_ROOT = cfg.dataDir + "/static";
    SECRET_KEY_FILE = cfg.secretKeyFile;
    DB_NAME = "${cfg.dataDir}/healthchecks.sqlite";
    ALLOWED_HOSTS = lib.concatStringsSep "," cfg.allowedHosts;
    DEBUG = boolToPython cfg.debug;
    REGISTRATION_OPEN = boolToPython cfg.registrationOpen;
  } // cfg.settings;

  environmentFile = pkgs.writeText "healthchecks-environment" (lib.generators.toKeyValue {} environment);

  healthchecksManageScript = with pkgs; (writeShellScriptBin "healthchecks-manage" ''
    sudo -u healthchecks sh -s "$@" <<"EOF"
      export $(cat ${environmentFile} | xargs);
      ${pkg}/bin/healthchecks-manage "$@"
    EOF
  '');
in
{
  options.services.healthchecks = {
    enable = mkEnableOption "healthchecks";
    allowedHosts = mkOption {
      type = types.listOf types.str;
      default = [ "*" ];
      description = ''
        The host/domain names that this site can serve.
      '';
    };

    listenAddress = mkOption {
      type = types.str;
      default = "[::1]";
      description = ''
        Address the server will listen on.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 8000;
      description = ''
        Port the server will listen on.
      '';
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/healthchecks";
      description = ''
        Storage path of healthchecks.
      '';
    };

    secretKeyFile = mkOption {
      type = types.path;
      description = ''
        Path to a file containing the secret key.
      '';
    };

    debug = mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable debug mode.
      '';
    };

    registrationOpen = mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        A boolean that controls whether site visitors can create new accounts. Set it to false if you are setting up a private Healthchecks instance,
        but it needs to be publicly accessible (so, for example, your cloud services can send pings to it).
        If you close new user registration, you can still selectively invite users to your team account.
      '';
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        Additional environment variables. See the <link xlink:href="https://healthchecks.io/docs/self_hosted_configuration/">documentation</link> for possible options.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ healthchecksManageScript ];

    systemd.targets.healthchecks = {
      description = "Target for all Healthchecks services";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "network-online.target" ];
    };

    systemd.services =
      let
        defaultServiceConfig = {
          WorkingDirectory = "${cfg.dataDir}";
          User = "healthchecks";
          Group = "healthchecks";
          StateDirectory = "healthchecks";
          StateDirectoryMode = "0750";
          EnvironmentFile = environmentFile;
        };
      in
      {
        healthchecks-migration = {
          description = "Healthchecks migrations";
          wantedBy = [ "healthchecks.target" ];

          serviceConfig = defaultServiceConfig // {
            Restart = "on-failure";
            Type = "oneshot";
            ExecStart = ''
              ${pkg}/bin/healthchecks-manage migrate
            '';
          };
        };

        healthchecks = {
          description = "Healthchecks WSGI Service";
          wantedBy = [ "healthchecks.target" ];
          after = [ "healthchecks-migration.service" ];

          preStart = ''
            ${pkg}/bin/healthchecks-manage collectstatic --no-input
            ${pkg}/bin/healthchecks-manage remove_stale_contenttypes --no-input
            ${pkg}/bin/healthchecks-manage compress
          '';

          serviceConfig = defaultServiceConfig // {
            Restart = "always";
            ExecStart = ''
              ${pkgs.python3Packages.gunicorn}/bin/gunicorn hc.wsgi \
                --bind ${cfg.listenAddress}:${toString cfg.port} \
                --pythonpath ${pkg}/opt/healthchecks
            '';
          };
        };

        healthchecks-sendalerts = {
          description = "Healthchecks Alert Service";
          wantedBy = [ "healthchecks.target" ];
          after = [ "healthchecks.service" ];

          serviceConfig = defaultServiceConfig // {
            Restart = "always";
            ExecStart = ''
              ${pkg}/bin/healthchecks-manage sendalerts
            '';
          };
        };

        healthchecks-sendreports = {
          description = "Healthchecks Reporting Service";
          wantedBy = [ "healthchecks.target" ];
          after = [ "healthchecks.service" ];

          serviceConfig = defaultServiceConfig // {
            Restart = "always";
            ExecStart = ''
              ${pkg}/bin/healthchecks-manage sendreports --loop
            '';
          };
        };
      };

    users.users.healthchecks = {
      isSystemUser = true;
      group = "healthchecks";
    };
    users.groups.healthchecks = { };
  };
}
