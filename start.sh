#!/bin/bash

# Start the server
conda run --no-capture-output -n lollms python app.py "$@"
