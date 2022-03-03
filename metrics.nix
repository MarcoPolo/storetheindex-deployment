indexerIP: { config, pkgs, ... }:
{

  services.grafana = {
    enable = true;
    port = 2342;
    domain = "metrics.marcopolo.io";
    addr = "127.0.0.1";
  };

  services.prometheus = {
    enable = true;
    port = 9001;
    globalConfig.scrape_interval = "15s";
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = 9002;
      };
    };
    scrapeConfigs = [
      {
        job_name = "local-node";
        static_configs = [{
          targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
        }];
      }
      {
        job_name = "storetheindex";
        static_configs = [{
          targets = [ "127.0.0.1:3002" ];
        }];
      }
      {
        job_name = "indexer-instance";
        static_configs = [{
          targets = [ "${indexerIP}:3002" ];
        }];
      }
    ];

  };

  services.nginx.virtualHosts.${config.services.grafana.domain} = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.grafana.port}";
      proxyWebsockets = true;
    };
  };

}
