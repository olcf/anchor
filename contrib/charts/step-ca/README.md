# Step CA Helm Chart

Chart for installing [smallstep
certificates](https://smallstep.com/certificates/), an open source PKI toolkit.
This chart is configured to automatically issue certificates for an existing CA
using the ACME protocol.

## Setup

An existing secret containing the CA key and signed certificate needs to exist
in this namespace. A new CA can be created by running the following from a host
with `origin-client` and [`cfssl`](https://github.com/cloudflare/cfssl)
installed. It will generate a signed certificate `ca.pem`, a key `ca-key.pem`,
and create a new secret in openshift.

```
echo '{"CN": "<Name of new CA>","hosts": [],"key": \
  {"algo": "rsa","size": 4096},"names": []}' | cfssl \
  gencert -initca - | cfssljson -bare ca -;
oc create secret generic "<Name of secret>" \
  --from-file ca-key.pem --from-file ca.pem;
```

This deployment makes a local copy of the upstream `smallstep/step-ca` image
from [here](https://hub.docker.com/r/smallstep/step-ca/) during image builds.
New deployments need to start an image build before the pods will be created.

## Values

Name | Description | Default
--- | --- | ---
replicaCount | Number of replicas pods to create | 1
stepURL | URL to use for Step CA |  step-ca.example.com
stepPort | External port to run Step CA on | 32756
stepCAName | Common Name of the CA Step CA is serving |
stepCAVersion | Version of step CA image to pull | 0.13.3
provisionerEmail | Email of account provisioning certificates | admin@fake.com
caSecretName | Existing secret contain the CA certificate and private key | ca-secret-name
whitelistedSubdomains | Subdomains that are allowed to access this service |
runAsUser | UID to run this pod as | 0
nameOverride | Value to use as `step-ca.name` instead of chart |
fullnameOverride | Value to use as `step-ca.fullname` instead of release + chart |
resources.limits.cpu | Limits on CPU usage for the step-ca container | 250m
resources.limits.memory | Limits on memory for the step-ca container | 250Mi

## Common Tasks
