#!/bin/bash

echo "Serving with dev config"
jekyll serve --config _config.yml,_config-dev.yml & open -a opera http://127.0.0.1:4000/