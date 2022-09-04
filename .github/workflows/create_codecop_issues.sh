#!/bin/bash

# create db* CODECOP issues
BUILD_DIR="$(dirname $0)"
cd $BUILD_DIR/../../database
../.tools/tvdcc/tvdcc.sh path=utils html=false excel=false validator=com.trivadis.tvdcc.validators.TrivadisGuidelines3Plus
