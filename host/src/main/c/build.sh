#!/bin/sh
gcc -I /opt/vc/include -L /opt/vc/lib -O2 -o test -lbcm_host test.c
#gcc -I /opt/vc/include -L /opt/vc/lib -o dispmanx -lbcm_host dispmanx.c
gcc -I /opt/vc/include -L /opt/vc/lib -O2 -o makeimage makeimage.c
