#!/bin/bash

stack test
stack exec elm-bridge

elm-package install --yes
elm-make frontend/Main.elm --output web/elm.js

