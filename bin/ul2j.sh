#!/bin/bash
SCRIPT_PATH="/Users/satkinson/Work/nowucca/ul2jekyll"
SCRIPT=ul2j.py
IN=/Users/satkinson/Work/nowucca/UlyssesPublishing
OUT=/Users/satkinson/Work/nowucca/nowucca.github.io

cd $SCRIPT_PATH
python3 "$SCRIPT_PATH/$SCRIPT" "$IN" "$OUT"
cd "$OUT"
