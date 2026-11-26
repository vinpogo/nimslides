## Compile-time discovery of modules, used by `features.nim`.

import std/[algorithm, macros, os, strutils]

macro importAll*(dir: string{lit}) =
  ## Imports every `.nim` file in `dir`, a path relative to the calling
  ## module, sorted by name. Other files are skipped; a missing or empty
  ## folder imports nothing. Mark the calling module with
  ## `{.warning[UnusedImport]: off.}`, since such modules are imported for
  ## their side effects only.
  result = newStmtList()
  let base = dir.lineInfoObj.filename.parentDir
  var names: seq[string]
  for kind, path in walkDir(base / dir.strVal):
    if kind in {pcFile, pcLinkToFile} and path.endsWith(".nim"):
      names.add path.splitFile.name
  names.sort()
  for name in names:
    result.add nnkImportStmt.newTree(newLit(dir.strVal & "/" & name))
