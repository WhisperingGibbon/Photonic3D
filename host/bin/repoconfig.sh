#!/bin/bash
# store per-repo settings in here
# then use:
# source repoconfig.sh
# to import them to different scripts

cpu=`uname -m`

if [ -z "$HOME" ] || [ "$HOME" == "/" ]; then
  HOME=~root
fi

DEFAULT_REPO="WhisperingGibbon/Photonic3D"
CONFIG_PROPS="${HOME}/3dPrinters/config.properties"

PHOTOCENTRIC_PORTNO=9091
PHOTOCENTRIC_PASSWD=photocentric
