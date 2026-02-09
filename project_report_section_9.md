# 9. 통합 모니터링 및 알림 체계 구축

해당 프로젝트에서는 Kubernetes 클러스터 및 애플리케이션의 안정적인 운영을 위해 **Node Exporter, Prometheus, Grafana, Alertmanager** 기반의 통합 모니터링 및 알림 시스템을 구축하였습니다.
해당 파트에서는 모니터링 구성 요소별 역할과 데이터 수집·시각화·알림 흐름을 중심으로 설명합니다.

## 9.1 모니터링 시스템 전체 구성 개요
모니터링 시스템은 클러스터 노드 및 애플리케이션 상태를 실시간으로 수집하고, 이를 시각화 및 알림 체계로 연계하는 구조로 설계하였습니다.

[ 모니터링 전체 구성 다이어그램 ]
각 구성 요소는 다음과 같은 역할을 수행합니다.
*   **Node Exporter**: 노드 자원 메트릭 수집
*   **Prometheus**: 메트릭 수집 및 저장
*   **Grafana**: 메트릭 시각화
*   **Alertmanager**: 장애 알림 전송 및 관리

## 9.2 Node Exporter 구성 및 역할
### 9.2.1 Node Exporter 도입 목적
Node Exporter는 인프라를 구성하는 각 노드의 CPU, 메모리, 디스크, 네트워크 상태를 수집하기 위해 사용하였습니다.

### 9.2.2 메트릭 수집 항목
Node Exporter를 통해 다음과 같은 주요 노드 자원 정보를 수집합니다.
*   **CPU**: 사용률 (User, System, Idle 등)
*   **Memory**: 사용량 및 가용량 (Total, Used, Free, Cache)
*   **Disk**: I/O 대역폭 및 디스크 사용량
*   **Network**: 트래픽 송수신량 (RX/TX) 및 패킷 에러
*   **System**: Load Average, Uptime 등

Node Exporter는 **DaemonSet** 또는 시스템 서비스 형태로 배포되어, 모든 노드에서 동일한 방식으로 메트릭을 수집하도록 구성하였습니다.

## 9.3 Prometheus 구성 및 메트릭 수집 구조
### 9.3.1 Prometheus 역할
Prometheus는 Node Exporter 및 Kubernetes 컴포넌트로부터 메트릭을 주기적으로 수집하고, **Time-Series(시계열) 데이터** 형태로 저장하는 중앙 메트릭 서버 역할을 수행합니다.

[ Prometheus Targets 화면 ]
[ Prometheus Metrics 조회 화면 ]

### 9.3.2 Kubernetes 연계 수집 구조
Prometheus는 **Service Discovery** 기능을 활용하여 Kubernetes의 Node, Pod, Service, API Server 등의 메트릭 타겟을 자동으로 탐지하고 수집하도록 구성하였습니다. 이를 통해 클러스터가 확장되거나 Pod가 재배포되어 IP가 변경되더라도 별도의 설정 수정 없이 모니터링 연속성이 유지됩니다.

## 9.4 모니터링 시스템 이중화 (High Availability)
안정적인 모니터링 환경을 보장하기 위해 **Keepalived와 HAProxy**를 활용한 고가용성(HA) 아키텍처를 적용하였습니다.

### 9.4.1 이중화 구성 아키텍처
모니터링 서버는 **Active-Standby** 구조로 이중화되어 있으며, **VIP(Virtual IP)**를 통해 서비스를 제공합니다.
*   **Keepalived (VRRP)**: 두 대의 모니터링 서버(Active/Backup) 간에 Heartbeat를 주고받으며, Active 서버 장애 시 즉시 Backup 서버로 VIP를 승계(Failover)합니다.
*   **HAProxy (Load Balancing)**: (필요 시) 인입되는 트래픽을 백엔드 Prometheus/Grafana 인스턴스로 부하 분산하거나, 특정 노드로 라우팅하여 서비스 가용성을 높입니다.

### 9.4.2 장애 감지 및 자동 절체
Master 노드의 장애(전원 차단, 네트워크 단절 등) 감지 시, Keepalived가 이를 즉시 인지하여 **1초 이내에 VIP를 Standby 노드로 이동**시킵니다. 이를 통해 운영자는 모니터링 서비스의 중단 없이 지속적으로 클러스터 상태를 관제할 수 있습니다.

## 9.5 Grafana 대시보드 구성 및 시각화
### 9.5.1 Grafana 도입 목적
Grafana는 Prometheus에 저장된 메트릭 데이터를 시각적으로 표현하여 클러스터 및 서비스 상태를 직관적으로 파악하기 위해 도입하였습니다.

### 9.5.2 대시보드 구성
관제 목적에 따라 다음과 같은 핵심 대시보드를 구성하였습니다.
*   **통합 노드 대시보드 (Node Overview)**: 전체 VM/Node의 CPU, Memory, Disk, Network 상태를 한눈에 파악
*   **Kubernetes 클러스터 현황**: Pod 배포 상태, 노드 자원 할당량, 클러스터 이벤트 모니터링
*   **서비스별 상세 대시보드**: Database, API Server 등 중요 애플리케이션 전용 뷰

[ Grafana 서비스 상태 대시보드 ]
이를 통해 운영자는 장애 발생 징후를 빠르게 인지하고, 리소스 사용 추이를 분석하여 사전 대응이 가능하도록 하였습니다.

## 9.6 Alertmanager 구성 및 장애 알림 처리
### 9.6.1 Alertmanager 역할
Alertmanager는 Prometheus에서 정의한 Alert Rule을 기반으로 임계치 초과 또는 장애 발생 시 알림을 전송하는 역할을 수행합니다.

### 9.6.2 알림 정책 구성
운영 안정성을 위해 다음과 같은 기준으로 알림 정책을 수립하였습니다.
*   **임계치 기반 알림**: CPU / Memory / System Load 사용률이 **45%**를 초과할 경우 'Critical' 등급 알림 발송
    > **[조건식 예시]** `100 - (avg by(instance)(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 45`

*   **알림 그룹화 및 억제**: 동일한 장애로 인한 알림 폭주를 방지하기 위해 Grouping 및 Inhibition 기능을 적용하여, 운영자가 핵심 알림에 집중할 수 있도록 구성하였습니다.

[ 중복 방지 + 알림 템플릿 화면 ]
[ 장애 발생 시 알림 수신 화면 (Email) ]

## 9.7 모니터링 및 운영 체계 적용 효과
모니터링 및 운영 시스템 구축을 통해 다음과 같은 효과를 확보하였습니다.
*   장애 발생 시 **신속한 인지(MTTR 단축)** 및 대응 가능
*   데이터 기반의 리소스 사용량 분석 및 **안정적인 용량 산정(Capacity Planning)**
*   자동화된 알림 체계를 통한 **24x365 무중단 관제 환경** 마련

## 9.8 마무리
Node Exporter, Prometheus, Grafana, Alertmanager를 연계하고 고가용성(HA)을 확보한 모니터링 체계를 통해, Kubernetes 클러스터와 애플리케이션 상태를 통합적으로 관리할 수 있는 환경을 구축하였습니다. 이를 통해 장애 대응 속도를 획기적으로 향상시키고, 안정적인 서비스 운영 기반을 마련하였습니다.
