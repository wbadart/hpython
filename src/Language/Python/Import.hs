{-# language DataKinds #-}
{-# language FlexibleContexts #-}
{-# language LambdaCase #-}
{-# language ScopedTypeVariables #-}

{-|
Module      : Language.Python.Import
Copyright   : (C) CSIRO 2017-2019
License     : BSD3
Maintainer  : Isaac Elliott <isaace71295@gmail.com>
Stability   : experimental
Portability : non-portable

`import`ing machinery
-}

module Language.Python.Import
  ( module Language.Python.Import.Error
    -- * Configuration
  , SearchConfig(..), mkSearchConfig
    -- * Finding and Loading
  , ModuleInfo(..)
  , LoadedModule(..)
  , findAndLoadAll
  , findModule
  , loadModule
  )
where

import Control.Lens.Fold ((^..), folded)
import Control.Lens.Getter ((^.), getting, to)
import Control.Lens.Review ((#), un, review)
import Control.Monad.Except (ExceptT(..), runExceptT)
import Data.Bifunctor (bimap)
import Data.Validation (validation, bindValidation)
import System.Directory (doesFileExist)
import System.FilePath ((<.>), (</>), takeDirectory)
import Unsafe.Coerce (unsafeCoerce)

import qualified Data.Map as Map

import Data.Type.Set (Member)
import Language.Python.Import.Error
  (AsImportError, _ImportNotFound, _ImportParseErrors, _ImportValidationErrors)
import Language.Python.Optics (_Statements, _SimpleStatements, _Import)
import Language.Python.Optics.Validated (unvalidated)
import Language.Python.Parse (SrcInfo, readModule)
import Language.Python.Syntax.Ident (identValue)
import Language.Python.Syntax.Import (_importAsName, _importAsQual)
import Language.Python.Syntax.Module (Module)
import Language.Python.Syntax.ModuleNames (ModuleName, unfoldModuleName)
import Language.Python.Syntax.Statement (Statement(..))
import Language.Python.Syntax.Types (importNames)
import Language.Python.Validate
  ( Indentation, Syntax, Scope
  , runValidateIndentation, runValidateSyntax, runValidateScope
  , validateModuleIndentation, validateModuleSyntax, validateModuleScope
  )
import Language.Python.Validate.Scope (moduleEntry)

data SearchConfig
  = SearchConfig
  { _scPythonPath :: FilePath
  , _scSearchPaths :: [FilePath]
  }

mkSearchConfig ::
  FilePath -> -- ^ Python executable path, e.g. @/usr/bin/python3.5@
  SearchConfig
mkSearchConfig pp =
  SearchConfig
  { _scPythonPath = pp
  , _scSearchPaths = fmap (takeDirectory pp </>) paths
  }
  where
    paths =
      [ ""
      , "lib" </> "python3.5"
      , "lib" </> "python3.5" </> "lib-dynload"
      , "lib" </> "python3.5" </> "site-packages"
      ]

data ModuleInfo a
  = ModuleInfo
  { _miName :: ModuleName '[] a
  , _miFile :: FilePath
  } deriving (Eq, Show)

-- |
-- Find a module by looking in the paths specified by 'SearchConfig'
findModule ::
  forall v e a.
  ( Member Syntax v
  , AsImportError e a
  ) =>
  SearchConfig ->
  ModuleName v a ->
  IO (Either e (ModuleInfo a))
findModule sc mn = search (_scSearchPaths sc)
  where
    search :: [FilePath] -> IO (Either e (ModuleInfo a))
    search [] = pure . Left $ _ImportNotFound.un unvalidated # mn
    search (path : rest) = do
      let file = path </> moduleFileName
      b <- doesFileExist file
      if b
        then pure $ Right ModuleInfo{ _miName = mn ^. unvalidated, _miFile = file }
        else search rest

    moduleDirs :: ([String], String)
    moduleDirs =
      bimap
        (fmap (^. getting identValue))
        (^. getting identValue)
        (unfoldModuleName mn)

    moduleFileName :: FilePath
    moduleFileName = foldr (</>) (snd moduleDirs <.> "py") (fst moduleDirs)

-- |
-- Load and validate a module
loadModule ::
  AsImportError e SrcInfo =>
  ModuleInfo SrcInfo ->
  IO (Either e (Module '[Syntax, Indentation] SrcInfo))
loadModule mi =
  runExceptT $ do
    mod <-
      ExceptT $
      validation (Left . review _ImportParseErrors) Right <$>
      readModule (_miFile mi)

    ExceptT . pure .
      validation (Left . review _ImportValidationErrors) Right $
      bindValidation
        (runValidateIndentation (validateModuleIndentation mod))
        (runValidateSyntax . validateModuleSyntax)

data LoadedModule v a
  = LoadedModule
  { _lmInfo :: ModuleInfo a
  , _lmTarget :: Module v a
  , _lmDependencies :: [(ModuleInfo a, Module v a)]
  } deriving (Eq, Show)

-- |
-- Find and load a module and its immediate dependencies
findAndLoadAll ::
  (Member Syntax v, AsImportError e SrcInfo) =>
  SearchConfig ->
  ModuleName v SrcInfo ->
  IO (Either e (LoadedModule '[Scope, Syntax, Indentation] SrcInfo))
findAndLoadAll sc mn =
  runExceptT $ do
    minfo <- ExceptT $ findModule sc mn
    mod <- ExceptT $ loadModule minfo

    let
      tlImports =
        mod ^..
        getting _Statements .
        to (\case
               SmallStatement _ s -> s ^.. getting _SimpleStatements
               _ -> []) .
        folded .
        getting _Import .
        importNames .
        folded

    deps <-
      traverse
        (\ias -> do
           let n = _importAsName ias
           res <- ExceptT $ findAndLoadAll sc (_importAsName ias)
           pure
             -- it's fine to skip skip scope checking for these two
             ( unsafeCoerce n
             , unsafeCoerce . snd <$> _importAsQual ias
             , _lmInfo res
             , _lmTarget res
             ))
        tlImports

    let
      scope =
        foldr
          (\(a, b, _, c) -> uncurry Map.insert $ moduleEntry a b c)
          Map.empty
          deps

    mod' <-
      ExceptT . pure $
      validation
        (Left . review _ImportValidationErrors)
        Right
        (runValidateScope scope $ validateModuleScope mod)

    pure $ LoadedModule minfo mod' ((\(_, _, c, d) -> (c, d)) <$> deps)