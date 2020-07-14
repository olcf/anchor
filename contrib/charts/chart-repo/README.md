# Helm Chart Repository Helm Chart (that's a bit redundant, right?)

Chart for installing a Helm chart repository. Used to provide packaged helm
charts from a central URL. Clients can add this URL to their helm clients and
use to install different versions of a chart using only a value file. This is
done by serving packaged charts from this URL along with an index file called
`index.yaml`. We create a file-server mirror of a remote Gitlab repository, and
generating a new index file along with packaging new chart versions whenever
thee remote repository has been updated.

This chart creates a pod with two containers, one running httpd to serve static
files, and another running [repowatch](https://github.com/kincl/repowatch) to
receive push events to the master branch at the [clusters charts
repository](https://example.com). Once a push event
has been received it runs repackages every chart using the `package_charts.sh`
script, and then updates the chart repository with `helm repo index .`.

## Setup

Repowatch needs to have an SSH key with pull access to the repository being
mirrored. Generate a key and add it to a user's account, then save it as a
kubernetes secret. Pass the name of this secret into this chart as the
`repowatchSSHSecret` value.

The packaged charts are stored in a persistent volume not managed by this
chart. Create a volume of whatever size you'd like, then assign the
its' value to the `helmRepoVolumeName` variable. This volume will be mounted in
the repowatch and httpd containers

This chart also needs to receive a webhook from a gitlab repository to trigger
updating the chart repository. Add a push events webhook to the gitlab
repository from `Settings > Integrations`.

## Values

Name | Description | Default
--- | --- | ---
replicaCount | Number of replicas pods to create | 1
helmVersion | Helm version to install into image | v2.14.3
helmRepoVolumeName | Name of persistent volume to mount in pod | example-volume
route.host | URL to serve Helm repository at | `chart-repo.example.com`
route.hookDomain | Subdomain to set up web hook at | `example.com`
gitlabUser| User to use to log into gitlab server over SSH | `gitlab`
gitlabServer| Gitlab server to SSH into | `gitlab.com`
repowatchProject | Gitlab project to mirror | `example-group/example-project`
repowatchSSHKeySecretName | Name of secret containing `id_rsa` to use for SSH read access to gitlab project |
gitlabHostKey | SSH Host key of the gitlab instance, wiil be added to `.ssh/known_hosts` |
runAsUser | UID to run this pod as | 0
resources.web.limits.cpu | Limits on CPU usage for the web-server container | 100m
resources.web.limits.memory | Limits on memory for the web-server container | 100M
resources.repowatch.limits.cpu | Limits on CPU usage for the repowatch container | 100m
resources.repowatch.limits.memory | Limits on memory for the repowatch container | 100M

## Common Tasks
