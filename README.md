# Cozystack Tenants

These tenants are copied from the Cozystack cluster

See also: [Cozystack Talm Demo repo][talm-demo]

[talm-demo]: https://github.com/kingdonb/cozystack-talm-demo

## Configuration

The Cozystack docs dictate the configuration for the initial tenant,
`tenant-root`. We are using a different subnet range, and we are using a
LoadBalancer group to provide stable services to the other tenants, who all
come and go.

For this reason we have diverged from the recommended configuration:

In the [get started guide][basic-apps] the docs recommend an isolated network.
We did not do that, so clients in `tenant-test` can reach Redis load balancers.

[basic-apps]: https://cozystack.io/docs/get-started/#setup-basic-applications

### tenant-root

To the default config, we have added according to the Cozystack get started
guide's directions: etcd, ingress, monitoring, persistent volumes & storage
(not part of a tenant) and OIDC via Keycloak which is temporarily exposed to
the public internet. The root ingress controller is only briefly allowed to
be exposed to the internet, so that certificate requests can be fulfilled.

```
tenant-root
├── helmrelease-etcd.yaml
├── helmrelease-ingress-nginx-system.yaml
├── helmrelease-ingress.yaml
├── helmrelease-monitoring.yaml
├── helmrelease-redis-live.yaml
├── helmrelease-redis-test.yaml
└── helmrelease-tenant-root.yaml
```

### tenant-test

In the test tenant, we provisioned two Kubernetes clusters: "cluster" and
"harvey" - they are both exposed to public Internet and users can authenticate
via Keycloak. Hence, normally, connecting to these public clusters implies that
you will at least briefly connect to the VPN so you can reach Keycloak and get
an OIDC token.

Harvey will host additional VClusters which do not have this VPN requirement.
They will OIDC via Dex, and use a public GitHub group to authenticate users.

The first VCluster will be named `moo`, second `mop`, if we need a third one
we will call it `vcluster` then if additional vclusters are needed, they will
likely go into a different tenant. For now there are only two tenants here.

```
tenant-test
├── helmrelease-kubernetes-cluster-cert-manager-crds.yaml
├── helmrelease-kubernetes-cluster-cert-manager.yaml
├── helmrelease-kubernetes-cluster-cilium.yaml
├── helmrelease-kubernetes-cluster-csi.yaml
├── helmrelease-kubernetes-cluster-fluxcd-operator.yaml
├── helmrelease-kubernetes-cluster-fluxcd.yaml
├── helmrelease-kubernetes-cluster-ingress-nginx.yaml
├── helmrelease-kubernetes-cluster.yaml
├── helmrelease-kubernetes-harvey-cert-manager-crds.yaml
├── helmrelease-kubernetes-harvey-cert-manager.yaml
├── helmrelease-kubernetes-harvey-cilium.yaml
├── helmrelease-kubernetes-harvey-cozy-victoria-metrics-operator.yaml
├── helmrelease-kubernetes-harvey-csi.yaml
├── helmrelease-kubernetes-harvey-fluxcd-operator.yaml
├── helmrelease-kubernetes-harvey-fluxcd.yaml
├── helmrelease-kubernetes-harvey-ingress-nginx.yaml
├── helmrelease-kubernetes-harvey-monitoring-agents.yaml
├── helmrelease-kubernetes-harvey.yaml
└── helmrelease-tenant-test.yaml
```

The architecture used to include a third tenant called `tenant-legacy`.
When there were stateful Virtual Machines in use, they would be hosted there.
In the new architecture, any stateful VMs are considered out of scope - they
can still be on either LAN subnet.

## Networks

There are several networks, some physical and some software-defined.

The two physical LAN subnets are 12-net and 13-net:

### 12-net

```
12-net (10.17.12.0/24)
├── dd-wrt.turkey.local (10.17.12.1) - GW
├── switch.turkey.local (10.17.12.2)
├── kingdon-mbp.turkey.local (10.17.12.102)
├── netmoom.turkey.local (10.17.12.109) - pi-hole DNS
├── brother-laser.turkey.local (10.17.12.199)
├── buffalo.turkey.local (10.17.12.200)
└── mikrotika-12net.turkey.local (10.17.12.249)
```

The 12-net subnet is the user machine network. It provides a direct NAT gateway
to the public internet, that works with video conferencing and most VPN tools.

It also hosts a color Brother laser printer, a file server that doubles as DNS,
a number of user machines, and a number of subnet routers.

The `netmoom` file server also hosts a pi-hole on Docker – the authoritative
DNS server for `turkey.local` – and other Docker containers (matchbox, dnsmasq,
a handful of Docker registry containers that serve as pull-through caches).

The `netmoom` file server also has a secondary interface, on the 13-subnet:

### 13-net

```
13-net (10.17.13.0/24)
├── dellwork01.turkey.local (10.17.13.174) - dynamically assigned range
├── dellwork02.turkey.local (10.17.13.7)
├── hpworker03.turkey.local (10.17.13.87)
├── hpworker05.turkey.local (10.17.13.102)
├── hpworker06.turkey.local (10.17.13.138)
├── root.turkey.local (10.17.13.241) - LoadBalancer
├── redis-test-lb.turkey.local (10.17.13.242)
├── redis-live-lb.turkey.local (10.17.13.243)
├── kube.turkey.local (10.17.13.244) - LoadBalancer
├── [unassigned] (10.17.13.245) ...
├── [unassigned] (10.17.13.246) ...
├── [unassigned] (10.17.13.247) ...
├── [unassigned] (10.17.13.248) - LoadBalancer
├── metnoom.turkey.local (10.17.13.250) - pi-hole Secondary DNS (on `metnoom`)
├── matchbox.turkey.local (10.17.13.251) - Docker hosted on `netmoom`
├── dnsmasq.turkey.local (10.17.13.252) - Docker hosted on `netmoom`
├── talos-dev-planevip.turkey.local (10.17.13.253) - cozystack Kubernetes VIP
├── netmoom.turkey.local (10.17.13.254) - pi-hole Primary DNS (on `netmoom`)
└── mikrotika-13net.turkey.local (10.17.13.249) - GW
```

The 13-net subnet is the Talos machine network. This is also the place for our
LoadBalancer IP addresses. It is divided into several informal ranges and one
DHCP range, `10.17.13.3` through `10.17.13.199` are reserved for DHCP clients.

The `mikrotika` device provides NAT to the 12-net and basic connectivity to the
public Internet, but the ingress is very limited because of only one public IP
to share across all subnets. A subnet boundary is used to protect the network
of user machines from accidental netbooting. The 13-net is configured for tftp
boot. The Talos cluster can be destroyed and recreated quickly, thanks to this!

`10.17.13.241` through `10.17.13.248` are dynamic load balancers. It is assumed
that half of the range is consumed as listed, and half will remain available.

### Planned Growth

It is anticipated that eventually, these manual load balancer ranges will be
made use of to host more stable services that should survive a cluster down/up.

`10.17.13.201-10.17.13.220`
`10.17.13.221-10.17.13.240`

These ranges are reserved for manually assigned LoadBalancers. It is assumed we
will not provision many LoadBalancerIPs dynamically, because we do not have an
external-dns plugin for PiHole and this will make things even more complicated.

Aside: I just learned there is actually an external-dns plugin for PiHole:
[doc link][external-dns-pihole]

[external-dns-pihole]: https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/pihole.md

## Health Checks

At some point during Cluster-UP, the root tenant redis instances are started, a
dashboard, keycloak, and observability service certificate are each issued by
LetsEncrypt, the OK function is blessed "Healthy" in an orderly fashion, and
the test tenant is then brought online.

Then, a DNS cname pivots from "root.turkey.local" to "kube.turkey.local" which
becomes the DMZ host for traffic on port 80/443. Any public services in either
subnet are routed via NGINX, either passthrough TLS or terminated in one of the
`tenant-test` clusters. The root cluster auth and dashboard are made private.

Every public-facing service is monitored at [public status][status-nerdland]
which hosts several public dashboard, and internal services will be monitored
at [private status][status-teamhephy], which should eventually live on 13-net
with the other network support services in that subnet (eg. DHCP, DNS, TFTP).

[status-nerdland]: https://status.nerdland.info/
[status-teamhephy]: https://status.teamhephy.info/

### Cluster Network

The default pod and service CIDR, gateway address, and join CIDR are all used.
The Cozystack root-host "moomboo.space" and api-server endpoint of the Kube VIP
address are all documented in the configs from the [Talm Demo repo][talm-demo].

The physical and virtual subnets (12 and 13-net, Pod and Service CIDR) are all
available through [Kingdon-CI][] GitHub Organization via a Tailscale Tailnet. 

The intention of this design is that groups in the `Kingdon-CI` org can be used
to provision access for developers, and those devs will not need to make public
any services which do not have a genuine need to be public.

They can work on a VCluster and provision Load Balancers or Ingress rules in a
private configuration, which only have any attack-surface or footprint behind
the VPN. This configuration is designed to be least-required and should remain
mostly secured against any external threat!

[Kingdon-CI]: https://github.com/kingdon-ci
