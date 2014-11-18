
-- | A module for 'FilePath' operations, to be used instead of "System.FilePath"
--   when writing build systems. In build systems, when using the file name
--   as a key for indexing rules, it is important that two different strings do
--   not refer to the same on-disk file. We therefore follow the conventions:
--
-- * Always use @\/@ as the directory separator, even on Windows.
--
-- * The 'normalise' function also squashes @\/..\/@ components.
module Development.Shake.FilePath(
    module System.FilePath,
    dropDirectory1, takeDirectory1, normalise,
    (-<.>),
    toNative, toStandard,
    exe
    ) where

import System.FilePath hiding (normalise)
import System.Info.Extra
import qualified System.FilePath as Native

infixr 7  -<.>


-- | Drop the first directory from a 'FilePath'. Should only be used on
--   relative paths.
--
-- > dropDirectory1 "aaa/bbb" == "bbb"
-- > dropDirectory1 "aaa/" == ""
-- > dropDirectory1 "aaa" == ""
-- > dropDirectory1 "" == ""
dropDirectory1 :: FilePath -> FilePath
dropDirectory1 = drop 1 . dropWhile (not . isPathSeparator)


-- | Take the first component of a 'FilePath'. Should only be used on
--   relative paths.
--
-- > takeDirectory1 "aaa/bbb" == "aaa"
-- > takeDirectory1 "aaa/" == "aaa"
-- > takeDirectory1 "aaa" == "aaa"
takeDirectory1 :: FilePath -> FilePath
takeDirectory1 = takeWhile (not . isPathSeparator)


-- | Normalise a 'FilePath', trying to do:
--
-- * All 'pathSeparators' become @\/@
--
-- * @foo\/bar\/..\/baz@ becomes @foo\/baz@
--
-- * @foo\/.\/bar@ becomes @foo\/bar@
--
-- * @foo\/\/bar@ becomes @foo\/bar@
--
--   This function is not based on the normalise function from the filepath library, as that function
--   is quite broken.
normalise :: FilePath -> FilePath
normalise xs | a:b:xs <- xs, isWindows && sep a && sep b = '/' : f ('/':xs) -- account for UNC paths being double //
             | otherwise = f xs
    where
        sep = Native.isPathSeparator
        f o = toNative $ deslash o $ (++"/") $ concatMap ('/':) $ reverse $ g 0 $ reverse $ split o

        deslash o x
            | x == "/" = case (pre,pos) of
                (True,True) -> "/"
                (True,False) -> "/."
                (False,True) -> "./"
                (False,False) -> "."
            | otherwise = (if pre then id else tail) $ (if pos then id else init) x
            where pre = sep $ head $ o ++ " "
                  pos = sep $ last $ " " ++ o

        g i [] = replicate i ".."
        g i ("..":xs) = g (i+1) xs
        g i (".":xs) = g i xs
        g 0 (x:xs) = x : g 0 xs
        g i (x:xs) = g (i-1) xs

        split xs = if null ys then [] else a : split b
            where (a,b) = break sep $ ys
                  ys = dropWhile sep xs


-- | Convert to native path separators, namely @\\@ on Windows. 
toNative :: FilePath -> FilePath
toNative = if isWindows then map (\x -> if x == '/' then '\\' else x) else id

-- | Convert all path separators to @/@, even on Windows.
toStandard :: FilePath -> FilePath
toStandard = if isWindows then map (\x -> if x == '\\' then '/' else x) else id


-- | Remove the current extension and add another, an alias for 'replaceExtension'.
(-<.>) :: FilePath -> String -> FilePath
(-<.>) = replaceExtension


-- | The extension of executables, @\"exe\"@ on Windows and @\"\"@ otherwise.
exe :: String
exe = if isWindows then "exe" else ""