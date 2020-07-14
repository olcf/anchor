#!/bin/bash

for i in $(find ./ -name Chart.yaml | cut -d '/' -f 2 ); do
  helm package "$i"
done
