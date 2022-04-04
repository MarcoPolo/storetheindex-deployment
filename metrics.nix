{ indexerIP, indexer2IP, gammazeroIndexerIP }: { config, pkgs, ... }:
{

  services.grafana = {
    enable = true;
    port = 2342;
    domain = "metrics.marcopolo.io";
    addr = "127.0.0.1";

    provision = {
      enable = true;
      datasources = [{
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:9001";
        isDefault = true;
      }];

      dashboards = [
        {
          name = "Indexer";
          options.path = "/etc/grafana/dashboards/indexer";
        }
        {
          name = "Read Load Generator";
          options.path = "/etc/grafana/dashboards/load-generators";
        }
      ];
    };
  };

  services.prometheus = {
    enable = true;
    port = 9001;
    globalConfig.scrape_interval = "15s";
    # To support read-load-generators emitting metrics
    pushgateway.enable = true;
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
        static_configs = [
          {
            targets = [ "${indexerIP}:3002" ];
          }
          {
            targets = [ "${indexer2IP}:3002" ];
          }
        ];
      }
      {
        job_name = "gammazero-indexer-instance";
        static_configs = [{
          targets = [ "${gammazeroIndexerIP}:3002" ];
        }];
      }
      {
        job_name = "read-load-generator";
        static_configs = [{
          targets = [ "localhost:9091" ];
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
