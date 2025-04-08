#!/bin/bash

BUILD_SRC=$(ls 20250409T000421--*)

echo "Tangling $BUILD_SRC"
emacs --batch --eval "(require 'org)" --eval "(org-babel-tangle-file \""$BUILD_SRC"\")"

echo "Running build.el"
emacs -Q --script build.el
