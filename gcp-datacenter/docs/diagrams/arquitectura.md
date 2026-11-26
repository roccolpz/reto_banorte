# Arquitectura: red hub-and-spoke, conectividad híbrida y cargas

```mermaid
flowchart LR
  subgraph onprem["on-prem simulado: acme-onprem-sim-vpc 192.168.0.0/16"]
    opvm["acme-onprem-sim-server 192.168.10.10<br/>HTTP + DNS corp.acme.internal"]
    oprouter["Cloud Routers ASN 65001<br/>us-central1 y us-east4"]
  end

  subgraph hub["acme-common-net-hub-vpc (acme-common-346e)"]
    havpn["HA VPN us-central1 + us-east4<br/>2 túneles por región, BGP"]
    hubrouter["Cloud Routers ASN 64514"]
    ncc(["NCC hub acme-common-net-hub"])
    dnsfwd["Cloud DNS: reenvío corp.acme.internal."]
  end

  subgraph dev["acme-dev-net-vpc"]
    devapp["app 10.10.0.0/20 us-central1"]
  end
  subgraph qa["acme-qa-net-vpc"]
    qaapp["app 10.20.0.0/20 us-central1"]
  end
  subgraph prod["acme-prod-net-vpc"]
    prodc1["app 10.30.0.0/20 us-central1"]
    prode4["app 10.31.0.0/20 us-east4 (DR)"]
  end

  oprouter <-->|"IPsec + BGP"| havpn
  havpn --- hubrouter
  hubrouter -->|"spoke híbrido"| ncc
  ncc -->|"spoke VPC"| dev
  ncc -->|"spoke VPC"| qa
  ncc -->|"spoke VPC"| prod
  dnsfwd -.->|"consultas DNS"| opvm
```

## Cargas de prod (primaria us-central1, DR us-east4)

```mermaid
flowchart LR
  user["Internet"] --> lb["Balanceador HTTPS global<br/>certificado administrado + Cloud Armor (OWASP)"]
  lb -->|"NEG serverless"| run["Cloud Run<br/>ingreso solo por el balanceador"]

  subgraph c1["us-central1 (primaria)"]
    gke["GKE privado acme-prod-app-gke"]
    mig["MIG sin IP externa<br/>imagen endurecida (acceso por IAP)"]
    sql["Cloud SQL primaria (PSA, CMEK)"]
    redis["Memorystore Redis"]
  end
  subgraph e4["us-east4 (DR)"]
    gkedr["GKE privado acme-prod-app-gke-dr"]
    sqldr["Cloud SQL réplica -dr (CMEK)"]
  end

  sql -->|"replicación"| sqldr
  sql --> vault["Backup and DR: bóveda acme-prod-data-vault"]
  binauthz{{"Binary Authorization<br/>attestor acme-prod-qa-approved"}} -.->|"solo imágenes firmadas"| gke
  binauthz -.-> gkedr
```

- Cada VPC de entorno tiene Cloud NAT por región para salida a Internet; ninguna VM tiene IP externa.
- Las zonas privadas `<env>.gcp.acme.internal.` viven en cada VPC de entorno; `corp.acme.internal.` se reenvía a on-prem.
- La administración por SSH entra por IAP (`35.235.240.0/20`), sin bastión público.
- Los planos de control de GKE son privados (`172.16.<n>.0/28`); el endpoint DNS se habilita solo durante un DR
  (runbook `dr-failover-cloudsql.md`, sección 4b).
- RPO ≤ 15 min y RTO ≤ 4 h (ADR 0014-j); el simulacro midió RPO 0 s y RTO 39 min (`registro/simulacro-dr-2026-11-25.md`).
- dev y qa tienen las mismas cargas en una sola región, sin réplica ni clúster DR.
