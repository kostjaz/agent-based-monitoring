global:
  scrape_interval: 15s

scrape_configs:
  - job_name: node
    static_configs:
      - targets:
          - node-exporter:9100
    relabel_configs:
      - target_label: instance
        replacement: __HOST_LABEL__

  - job_name: vmagent
    static_configs:
      - targets:
          - localhost:8429
    relabel_configs:
      - target_label: instance
        replacement: __HOST_LABEL__-vmagent

