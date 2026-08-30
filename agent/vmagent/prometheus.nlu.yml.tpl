global:
  scrape_interval: 15s

scrape_configs:
  - job_name: node
    static_configs:
      - targets:
          - node-exporter:9100
    relabel_configs:
      - target_label: host
        replacement: __HOST_LABEL__
      - target_label: instance
        replacement: __HOST_LABEL__
      - target_label: job
        replacement: __REGION_LABEL__
    metric_relabel_configs:
      - source_labels:
          - __name__
        regex: node_uname_info
        target_label: nodename
        replacement: __HOST_LABEL__

  - job_name: nvidia-gpu
    static_configs:
      - targets:
          - nvidia-gpu-exporter:9835
    relabel_configs:
      - target_label: host
        replacement: __HOST_LABEL__
      - target_label: instance
        replacement: __HOST_LABEL__
      - target_label: job
        replacement: __REGION_LABEL__

  - job_name: vmagent
    static_configs:
      - targets:
          - localhost:8429
    relabel_configs:
      - target_label: host
        replacement: __HOST_LABEL__
      - target_label: instance
        replacement: __HOST_LABEL__-vmagent

  - job_name: cadvisor
    static_configs:
      - targets:
          - cadvisor:8080
    relabel_configs:
      - target_label: host
        replacement: __HOST_LABEL__
      - target_label: instance
        replacement: __HOST_LABEL__
      - target_label: job
        replacement: __REGION_LABEL__
      - target_label: exporter
        replacement: cadvisor

  - job_name: optional-exporters
    file_sd_configs:
      - files:
          - /etc/vmagent/optional-targets/*.yml
    relabel_configs:
      - target_label: host
        replacement: __HOST_LABEL__
      - target_label: instance
        replacement: __HOST_LABEL__
      - target_label: job
        replacement: __REGION_LABEL__
