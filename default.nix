{ self ? null }:
{ pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  config, ...
}@args:

let
  cfg = config.services.fastapi-dls;
  envVars = {
    DEBUG = builtins.toString cfg.debug;
    DLS_URL = cfg.listen.ip;
    DLS_PORT = builtins.toString cfg.listen.port;
    TOKEN_EXPIRE_DAYS = builtins.toString cfg.authTokenExpire;
    LEASE_EXPIRE_DAYS = builtins.toString cfg.lease.expire;
    LEASE_RENEWAL_PERIOD = builtins.toString cfg.lease.renewalPeriod;
    DATABASE = "sqlite:////var/lib/fastapi-dls/db.sqlite";
    INSTANCE_KEY_RSA = "/var/lib/fastapi-dls/instance.private.pem";
    INSTANCE_KEY_PUB = "/var/lib/fastapi-dls/instance.public.pem";
    SUPPORT_MALFORMED_JSON = builtins.toString cfg.supportMalformedJSON;
  } // lib.optionalAttrs (cfg.timezone != null) {
    TZ = cfg.timezone;
  } // cfg.extraOptions;
  package = if self == null then import ./package.nix { inherit pkgs; }
    else self.outputs.packages.${pkgs.stdenv.targetPlatform.system}.default;
in
{
  options = {
    services.fastapi-dls = {
      enable = lib.mkEnableOption "minimal Delegated License Service (DLS)";
      debug = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Toggle fastapi debug mode.";
      };
      timezone = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "America/Montreal";
        description = "Timezone for fastapi-dls instance, null defaults to system timezone.";
      };
      listen.ip = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        example = "192.168.69.1";
        description = "IP which fastapi-dls should listen on.";
      };
      listen.port = lib.mkOption {
        type = lib.types.port;
        default = 443;
        description = "Port which fastapi-dls should listen on.";
      };
      authTokenExpire = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Client auth-token (not .tok token!) validity in days.";
      };
      lease.expire = lib.mkOption {
        type = lib.types.int;
        default = 90;
        description = "Lease time in days.";
      };
      lease.renewalPeriod = lib.mkOption {
        type = lib.types.float;
        default = 0.15;
        description = ''
          The percentage of the lease period that must elapse before a licensed client can renew a license.
          For example, if the lease period is one day and the renewal period is 20%, the client attempts to
          renew its license every 4.8 hours. If network connectivity is lost, the loss of connectivity is
          detected during license renewal and the client has 19.2 hours in which to re-establish
          connectivity before its license expires.
        '';
      };
      supportMalformedJSON = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Support parsing for mal formatted \"mac_address_list\"";
      };
      extraOptions = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        example = {
          INSTANCE_KEY_RSA = "/home/user/fastapi-dls/instance.private.pem";
          INSTANCE_KEY_PUB = "/home/user/fastapi-dls/instance.public.pem";
        };
        description = "Extra environment variables to pass to fastapi-dls.";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.services.fastapi-dls = {
      description = "Service for fastapi-dls";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = envVars;

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = "fastapi-dls";
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        WorkingDirectory = "/var/lib/fastapi-dls";
        ExecStart = "${lib.getBin package}/bin/fastapi-dls";
        Restart = "always";
        KillSignal = "SIGQUIT";
        NotifyAccess = "all";
      };
    };
  };
}
