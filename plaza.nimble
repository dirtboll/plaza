# Package

version       = "0.1.0"
author        = "i.gede97@ui.ac.id"
description   = "A game"
license       = "MIT"
srcDir        = "src"
bin           = @["plaza"]
binDir        = "bin"


# Dependencies

requires "nim >= 1.6.6"
requires "nimgl"
requires "glm"
requires "polymorph"