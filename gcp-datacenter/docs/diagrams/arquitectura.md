# Arquitectura de red: hub-and-spoke con NCC y HA VPN

```mermaid
flowchart LR
  subgraph onprem["onprem-sim (simula el centro de datos) 192.168.0.0/16"]
    opvm["VM servidor<br/>HTTP + DNS corp.acme.internal<br/>192.168.10.0/24"]
    oprouter["Cloud Router<br/>ASN 65001"]
  end

  subgraph hub["acme-common-net-hub: VPC hub 10.0.0.0/16"]
    hubrouter["Cloud Router<br/>ASN 64514"]
    havpn["HA VPN<br/>2 túneles, BGP"]
    ncc(["NCC hub"])
    dnsfwd["Cloud DNS<br/>reenvío corp.acme.internal."]
  end

  subgraph dev["acme-dev-net-host: VPC dev"]
    devapp["app 10.10.0.0/20<br/>us-central1"]
  end
  subgraph qa["acme-qa-net-host: VPC qa"]
    qaapp["app 10.20.0.0/20<br/>us-central1"]
  end
  subgraph prod["acme-prod-net-host: VPC prod"]
    prodc1["app 10.30.0.0/20<br/>us-central1"]
    prode4["app 10.31.0.0/20<br/>us-east4 (DR)"]
  end

  oprouter <-->|"IPsec + BGP"| havpn
  havpn --- hubrouter
  hubrouter -->|"spoke híbrido"| ncc
  ncc -->|"spoke VPC"| dev
  ncc -->|"spoke VPC"| qa
  ncc -->|"spoke VPC"| prod
  dnsfwd -.->|"consultas DNS"| opvm

  subgraph svc["Proyectos de servicio (Shared VPC)"]
    gke["GKE privado"]
    mig["MIG sin IP externa"]
    sql["Cloud SQL IP privada (PSA)"]
  end
  prod --- svc
```

- Cada VPC de entorno tiene Cloud NAT por región para salida a Internet; ninguna VM tiene IP externa.
- Las zonas privadas `<env>.gcp.acme.internal.` viven en cada VPC de entorno; `corp.acme.internal.` se reenvía a on-prem.
- La administración por SSH entra por IAP (`35.235.240.0/20`), sin bastión público.
