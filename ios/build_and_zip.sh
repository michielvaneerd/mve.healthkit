#!/bin/bash

ti build -p ios --build-only
# mve.healthkit-iphone-1.0.0.zip
unzip -o dist/mve.healthkit-iphone-*.zip -d ../example_not_included/

