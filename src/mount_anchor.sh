#!/bin/sh
#
# Mount an image

. /lib/anchor_auth.sh
. /lib/anchor_image.sh

# Authenticate to image store
anchor_auth

# Fetch and mount image
anchor_image
