# Mutual TLS Docker Registry Proxy

Helm chart to install a mutual TLS front end proxy to communicate with a docker
registry internal to Kubernetes. Terminates TLS connections from an external
route, re-encrypts them to the internal registry with an Authorization header
set.

## Setup

To install a new deployment we first need a TLS certificate for our endpoint.

```
echo
'{"CN":"mtls-registry-moderate-production","key":{"algo":"rsa","size":4096}}' |
cfssl gencert -config ./ca-config.json -ca ca.pem -ca-key ca-key.pem   -profile
"host services" -hostname "mtls-registry.example.com" - |   cfssljson
-bare mtls

cat ./mtls.pem ./mtls-key.pem  >> ./cert.pem
oc create secret generic mtls-moderate-production --from-file ca.pem
--from-file cert.pem=cert.pem

rm -f ./cert.pem ./mtls.*
```
