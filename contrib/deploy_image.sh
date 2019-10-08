#!/bin/bash

# Copy images to a PVC running in openshift, and set host links to those images
# Reads in INPUT_ARRAY, MACHINE_DOMAIN, DEPLOY_REGISTRY_URL, TILLER_NAMESPACE,
# ADVIL_CA_SECRET, and CI_COMMIT_REF_NAME from the env

# Debugging flag
set -x

setup_deployment() {
  # Delete existing deployment to wipe the PVC
  echo "Deleting existing deployment"
  helm delete --purge "$CI_COMMIT_REF_NAME"
  echo "Deployment deleted"

  # Sleep b/c pvc delete can take a second
  echo "Deleting PVC"
  while true; do
    oc get pvc "${CI_COMMIT_REF_NAME}-anchor-deploy" &> /dev/null;
    if [[ "$?" != "0" ]]; then echo "PVC deleted"; break; fi;
  done

  # Create new deployment
  echo "Installing new deployment"
  helm install -n "$CI_COMMIT_REF_NAME" \
    --set subdomain="${MACHINE_DOMAIN}" \
    --wait \
    ./anchor-deploy
  echo "Deployment installed"

  # Get pod name for deployment
  while true; do
    POD=$(oc get pods -o template \
      -l deploymentconfig="${CI_COMMIT_REF_NAME}"-anchor-deploy \
      --template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | tail -n 1);
    [[ -z "$POD" ]] || break;
  done
  echo "Deployment pod is ${POD}"

}

# Read a host string using pdsh bracketed expansion
# Valid examples are as follows
# host[1-2].local
# host[1-10,14,200-201].local
# host4.local
host_expansion() {
  INPUT="$1"

  # Check if this even needs to be expanded
  if ! [[ "$INPUT" =~ [ ]] && ! [[ "$INPUT" =~ ] ]]; then
    echo "$INPUT";
    return
  fi

  # Grab the values of the input arg, saving the pre/suffix
  prefix=$(echo "$INPUT" | cut -d '[' -f 1)
  suffix=$(echo "$INPUT" | cut -d ']' -f 2)
  values=${INPUT#"$prefix"}
  values=${values#"["}
  values=${values%"$suffix"}
  values=${values%"]"}

  # Pass in the values, grabbing each comma-delimited 'segment'. If the segment
  # has a -, expand it using seq. Otherwise just append it to HOST_NUMBER array
  HOST_NUMBERS=()
  while IFS=',' read -ra SEG_ARRAY; do
    for SEGMENT in "${SEG_ARRAY[@]}"; do
      if [[ $SEGMENT =~ - ]]; then
        START=$(echo "$SEGMENT" | cut -d '-' -f 1)
        END=$(echo "$SEGMENT" | cut -d '-' -f 2)
        for ENTRY in $(seq "$START" "$END"); do
          HOST_NUMBERS+=("$ENTRY")
        done
      else
        HOST_NUMBERS+=("$SEGMENT")
      fi
    done
  done < <(echo "$values")

  # Use saved pre/suffix with built HOST_NUMBER array to build the full host
  # list
  HOST_ARRAY=()
  for NUM in "${HOST_NUMBERS[@]}"; do
    HOST_ARRAY+=("${prefix}${NUM}${suffix}")
  done

  echo "${HOST_ARRAY[@]}"
}

copy_images_set_links() {
  for input in "${INPUT_ARRAY[@]}"; do
    HOSTS=$(echo "$input" | cut -d'/' -f '1')
    IMAGE=$(echo "$input" | cut -d'/' -f '2')

    # Download squashed image and mount it
    CONTAINER=$(buildah from --authfile "${AUTH_FILE}" \
      "${DEPLOY_REGISTRY_URL}/${IMAGE}")
    MOUNT=$(buildah mount "${CONTAINER}")

    # Copy /boot and ca cert to HTTP endpoint
    oc rsh "${POD}" mkdir -p "/var/www/html/${IMAGE}"
    oc rsh "${POD}" mkdir -p "/var/www/html/${IMAGE}/boot"
    oc rsync "${MOUNT}/boot/" "${POD}:/var/www/html/${IMAGE}/boot"

    # Cleanup
    buildah umount "${CONTAINER}"
    buildah rm "${CONTAINER}"
    buildah rmi "${DEPLOY_REGISTRY_URL}/${IMAGE}"

    for HOST in $(host_expansion "$HOSTS"); do
      # Set host link to image
      oc rsh "${POD}" mkdir -p /var/www/html/hosts/
      oc rsh "${POD}" ln -f -s "../${IMAGE}" "/var/www/html/hosts/${HOST}"
      # Set tags in openshift registry to image
      oc tag "${IMAGE}" "${CI_COMMIT_REF_NAME}:${HOST}"
    done

  done
}

# gitlab-ci wraps variables in quotes. Can't directly define an array. Opted
# for semi-colon delimited list
IFS=';' read -ra INPUT_ARRAY <<< "$(echo "$INPUT_ARRAY" | tr -d ' \n')"
echo "${INPUT_ARRAY[@]}"

setup_deployment
copy_images_set_links
