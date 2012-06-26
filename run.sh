#!/bin/bash

pushd ~/env-monitor/

while [ true ] ; do coffee monitor.coffee ; sleep 2 ; done

popd
