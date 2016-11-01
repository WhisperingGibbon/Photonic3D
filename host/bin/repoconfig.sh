#!/bin/bash
# store per-repo settings and variables in here
# then use:
# source repoconfig.sh
# to import them to different scripts

cpu=`uname -m`

if [ -z "$HOME" ] || [ "$HOME" == "/" ]; then
  HOME=~root
fi

DEFAULT_REPO="WhisperingGibbon/Photonic3D"
DEV_REPO="Photocentric3D/Photonic3D-Dev"
TESTKIT_REPO="Photocentric3D/Photonic3D"
TESTKITDEV_REPO="WesGilster/Creation-Workshop-Host"

CONFIG_PROPS="${HOME}/3dPrinters/config.properties"

PHOTOCENTRIC_PORTNO=9091
PHOTOCENTRIC_PASSWD=photocentric
