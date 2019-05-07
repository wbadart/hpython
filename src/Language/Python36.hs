{-|
Module      : Language.Python36
Copyright   : (C) CSIRO 2017-2019
License     : BSD3
Maintainer  : Isaac Elliott <isaace71295@gmail.com>
Stability   : experimental
Portability : non-portable

@hpython@ provides tools for working with Python source code.

"Language.Python36.DSL": A DSL for writing Python programs

"Language.Python36.Optics": Optics for working with Python syntax trees

"Language.Python36.Parse": Parse Python source into a syntax tree

"Language.Python36.Render": Pretty print Python syntax trees

"Language.Python36.Syntax": The data structures that represent Python programs, like 'Statement' and 'Expr'

"Language.Python36.Validate": Validate aspects of Python syntax trees, like indentation, syntax, or scope

-}

module Language.Python36
  ( module Language.Python36.DSL
  , module Language.Python36.Optics
  , module Language.Python36.Parse
  , module Language.Python36.Render
  , module Language.Python36.Syntax
  , module Language.Python36.Validate
  )
where

import Language.Python36.DSL
import Language.Python36.Optics
import Language.Python36.Parse
import Language.Python36.Render
import Language.Python36.Syntax
import Language.Python36.Validate
