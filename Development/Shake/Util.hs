
-- | A module for useful utility functions for Shake build systems.
module Development.Shake.Util(
    parseMakefile, needMakefileDependencies, neededMakefileDependencies,
    shakeArgsAccumulate
    ) where

import Development.Shake
import Development.Shake.Rules.File
import qualified Data.ByteString.Char8 as BS
import qualified Development.Shake.ByteString as BS
import Data.Tuple.Extra
import Data.List
import System.Console.GetOpt


-- | Given the text of a Makefile, extract the list of targets and dependencies. Assumes a
--   small subset of Makefile syntax, mostly that generated by @gcc -MM@.
--
-- > parseMakefile "a: b c\nd : e" == [("a",["b","c"]),("d",["e"])]
parseMakefile :: String -> [(FilePath, [FilePath])]
parseMakefile = map (BS.unpack *** map BS.unpack) . BS.parseMakefile . BS.pack


-- | Depend on the dependencies listed in a Makefile. Does not depend on the Makefile itself.
--
-- > needMakefileDependencies file = need . concatMap snd . parseMakefile =<< liftIO (readFile file)
needMakefileDependencies :: FilePath -> Action ()
needMakefileDependencies file = needBS . concatMap snd . BS.parseMakefile =<< liftIO (BS.readFile file)


-- | Depend on the dependencies listed in a Makefile. Does not depend on the Makefile itself.
--   Use this function to indicate that you have /already/ used the files in question.
--
-- > neededMakefileDependencies file = needed . concatMap snd . parseMakefile =<< liftIO (readFile file)
neededMakefileDependencies :: FilePath -> Action ()
neededMakefileDependencies file = neededBS . concatMap snd . BS.parseMakefile =<< liftIO (BS.readFile file)


-- | Like `shakeArgsWith`, but instead of accumulating a list of flags, apply functions to a default value.
--   Usually used to populate a record structure. As an example of a build system that can use either @gcc@ or @distcc@ for compiling:
--
-- @
--import System.Console.GetOpt
--
--data Flags = Flags {distCC :: Bool} deriving Eq
--flags = [Option \"\" [\"distcc\"] (NoArg $ Right $ \\x -> x{distCC=True}) \"Run distributed.\"]
--
--main = 'shakeArgsAccumulate' 'shakeOptions' flags (Flags False) $ \\flags targets -> return $ Just $ do
--     if null targets then 'want' [\"result.exe\"] else 'want' targets
--     let compiler = if distCC flags then \"distcc\" else \"gcc\"
--     \"*.o\" '*>' \\out -> do
--         'need' ...
--         'cmd' compiler ...
--     ...
-- @
--
--   Now you can pass @--distcc@ to use the @distcc@ compiler.
shakeArgsAccumulate :: ShakeOptions -> [OptDescr (Either String (a -> a))] -> a -> (a -> [String] -> IO (Maybe (Rules ()))) -> IO ()
shakeArgsAccumulate opts flags def f = shakeArgsWith opts flags $ \flags targets -> f (foldl' (flip ($)) def flags) targets
