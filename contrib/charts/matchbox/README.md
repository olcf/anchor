# Matchbox Helm Chart

Chart for installing a [matchbox](https://coreos.com/matchbox) server. Used to
provide rendered iPXE configuration files to hosts keyed off their hostnames.
Creates a group for each defined host, and matches that group to a defined iPXE
configuration profile.

### Traditional Matchbox Config

For example, say you have a host you want to boot. First define a group named
`node1`, and assign that group a set of selectors that are unique to the
machine group. Each selector must be matched by a node trying to identify as
part of that group. The selectors can be off MAC address, IP address, or any
custom label. It's probably easiest to leave it assigned as a hostname though.
Then assign this machine group to a profile which contains the actual
configuration. An complete example in YAML is below.

```yaml
node1:
  selector:
    hostname: node1
  profile: imageA
```

Next we need to define the profile used for this host, in this case `imageA`.
This is a network boot configuration, and could be a Container/Ignition/Cloud
Config, but for us we just want it to serve an iPXE config. An example
definition in YAML is below.

```yaml
imageA;
  id: etcd
  name: Container Linux with etcd2
  cloud_id:
  ignition_id: etcd.yaml
  generic_id: some-service.cfg
  boot:
    kernel: /assets/coreos/1576.4.0/coreos_production_pxe.vmlinuz
    initrd: [/assets/coreos/1576.4.0/coreos_production_pxe_image.cpio.gz]
    args:
      coreos.config.url=http://matchbox.foo:8080/ignition?uuid=${uuid}&mac=${mac:hexhyp}
      coreos.first_boot=yes
      coreos.autologin
```

Most of these parameters we don't care about since we're only using iPXE.
Therefore only the `boot` hash is passed up to the chart's input values.

### Regular Expressions, Default Values, and Other Opinionated Decisions

For a small subset of nodes, defining the profile for each group is fine. At
larger scales though managing upgrades/separate profiles can be a pain. This
helm chart adds a feature to assign profiles to a set of machine groups that
match a list of regular expressions.

In that same vein defining a selector for a node as the name of the machine
group feels redundant. If a machine group does not have a selector defined, it
creates one for a hostname matching the key name. For example, `node: {}`
becomes `node1: {selector: {hostname: node1}}`.

Complicated DHCP configs are unwieldy/difficult to manage. If you point a node
to the `/boot.ipxe` endpoint, it renders out a chained file with the node
parameters passed as inputs (`/ipxe?uuid=${uuid}&mac=${mac:hexhyp}&domain=${domain}&hostname=${hostname}&serial=${serial}`).

## Values

Name | Description | Default
--- | --- | ---
replicaCount | Number of replicas pods to create | 2
externalRoute | HTTP URL to access matchbox | `matchbox.example.com`
matchboxVersion | Matchbox image version to pull | v0.8.0
runAsUser | UID to run this pod as | 0
nameOverride | Value to use as `matchbox.name` instead of chart |
fullnameOverride | Value to use as `matchbox.fullname` instead of release + chart |
resources.limits.cpu | Limits on CPU usage for the matchbox container | 50m
resources.limits.memory | Limits on memory for the matchbox container | 64Mi
profiles | Hash of profiles to use. Passes options for each key as the `boot` hash. Creates a formatted JSON file for each. |
groupRegexProfiles | Hash of regular expressions to assign profiles. Adds the `profile` value of each key to the matching groups |
groups | Hash of machine groups to define |

## Common Tasks
