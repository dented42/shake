
module Test.Manual(main) where

import Development.Shake hiding (copyFileChanged)
import Development.Shake.FilePath
import Test.Type
import General.Extra
import Data.Maybe
import System.Info.Extra


main = shakeTest_ test $
    action $ fail "The 'manual' example should only be used in test mode"

test build = do
    -- we use .git as our destination, despite not being a real git repo
    -- so that search tools ignore it, and I don't get dupes for every source file
    let dest = ".git"
    copyDirectoryChanged (root </> "docs/manual") dest
    copyDirectoryChanged (root </> "src/Development") $ dest </> "Development"
    copyDirectoryChanged (root </> "src/General") $ dest </> "General"
    copyFileChanged (root </> "src/Paths.hs") $ dest </> "Paths_shake.hs"
    (_, gccPath) <- findGcc
    let opts = [Cwd dest, Shell, AddPath [] (maybeToList gccPath)]
    let cmdline = if isWindows then "build.bat" else "/bin/sh build.sh"
    cmd_ opts cmdline "-j2"
    assertExists $ dest </> "_build/run" <.> exe
    cmd_ opts cmdline
    cmd_ opts [cmdline,"clean"]
    assertMissing $ dest </> "_build/run" <.> exe
