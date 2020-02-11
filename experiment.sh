#!/bin/sh

# print every command
set -x

python cli/run.py

PYTHONPATH=$PWD python cli/run.py

python -m cli.run
