# Monitoring Infrastructure Ansible Playbook

이 프로젝트는 Prometheus, Grafana, Alertmanager 기반의 모니터링 스택을 Ansible을 통해 자동으로 설치·구성하는 인프라 템플릿입니다.
Exporter 설치부터 Nginx + Certbot 기반 HTTPS 프록시까지 전 과정을 포함하며, 모든 구성 요소는 Docker 및 systemd 기반으로 실행됩니다.

## 📦 구성 요소

| 구성 요소          | 설명                                                      |
|-------------------|-----------------------------------------------------------|
| **Prometheus**    | 메트릭 수집 및 저장                                       |
| **Grafana**       | 시각화 대시보드 제공                                      |
| **Alertmanager**  | 경고(알람) 수신 및 분배                                   |
| **Nginx**         | 리버스 프록시 및 HTTPS 트래픽 처리                        |
| **Certbot**       | Let's Encrypt 기반 인증서 자동 발급 및 갱신               |
| **node_exporter** | 서버 리소스(CPU, 메모리 등) 메트릭 수집                   |
| **mysql_exporter**| MySQL 성능 및 상태 모니터링                               |
| **blackbox_exporter** | HTTP/HTTPS 외부 탐지용 프로브 (헬스체크 기반 알람 설정 등) |
| **Common**        | 공통 패키지 설치 및 초기 셋업                             |

## 📁 프로젝트 구조

```bash
ansible/
├── ansible.cfg
├── inventory.ini
├── example.inventory.ini
├── group_vars/
│   ├── all.yml
│   └── example.all.yml
├── roles/
│   ├── alertmanager/
│   ├── blackbox_exporter/
│   ├── certbot/
│   ├── common/
│   ├── grafana/
│   ├── mysql_exporter/
│   ├── nginx/
│   ├── node_exporter/
│   └── prometheus/
└── site.yml
```


## 🚀 사용 방법

### 1. 인벤토리 설정

`inventory.ini` 또는 `example.inventory.ini` 파일에 서버 및 exporter 목록을 설정합니다.

```ini
[monitoring]
monitoring-instance ansible_host=10.0.0.2 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[monitoring_targets_dev]
backend-dev ansible_host=10.10.0.2 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
mysql-dev ansible_host=10.10.20.2 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[exporters]
node-exporter-dev ansible_host=10.10.0.2 role=node environment=dev port=9100
mysql-exporter-dev ansible_host=10.10.20.2 role=mysql environment=dev port=9104
blackbox-exporter ansible_host=10.0.0.2 role=blackbox environment=dev port=9115
```

### 2. 변수 설정

`group_vars/all.yml` 파일에서 다음과 같이 도메인 및 서비스 설정 값을 정의합니다.

```yaml
monitoring_domains:
  prometheus: prometheus.onthe-top.com
  grafana: grafana.onthe-top.com
  alertmanager: alertmanager.onthe-top.com

certbot_email: guinnessoverflow@gmail.com
```

### 3. Playbook 실행

```bash
ansible-playbook -i inventory.ini site.yml
```

### 4. 인증서 갱신
인증서는 certbot Role을 통해 자동으로 갱신됩니다.
(renew cronjob + nginx reload hook 포함)

## 🌐 접근 URL

| 서비스        | 예시 도메인                        |
|---------------|-------------------------------------|
| Prometheus    | https://prometheus.onthe-top.com    |
| Grafana       | https://grafana.onthe-top.com       |
| Alertmanager  | https://alertmanager.onthe-top.com  |

## ⚙️ 기타 관리 방법

| 작업 항목                              | 방법                                                                 |
|----------------------------------------|----------------------------------------------------------------------|
| 메트릭 수집 대상 추가                  | `inventory.ini`, `exporters` 그룹에 서버 및 포트 추가               |
| Grafana 대시보드/데이터소스 변경       | `roles/grafana/files/provisioning/` 내 파일 수정                    |
| Prometheus Alert rule 추가/수정        | `roles/prometheus/files/alert-rules.yml` 수정 후 Playbook 실행      |
| 인증서 만료 대응                       | `certbot` role이 자동으로 주기적 갱신 + `nginx reload`까지 수행     |
| Exporter 추가 (Node/MySQL/Blackbox 등) | `exporters` 그룹에 정의 + role 할당 (자동 등록됨)                   |

## 📎 참고

- 모든 Exporter는 systemd 서비스로 등록되어 서버 재부팅 후에도 자동 실행됩니다.
- Prometheus에서 exporters 목록은 Ansible 템플릿 기반(`prometheus.yml.j2`)으로 자동 생성됩니다.
- Blackbox Exporter는 HTTP 헬스체크 기반 알람 감지를 위해 구성되며, 해당 대상은 Prometheus 설정에서 URL 기준 라벨링됩니다.
