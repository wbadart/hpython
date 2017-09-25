module Test.Language.Python.Parser.Indentation (makeIndentationTests) where

import Papa
import GHC.Stack
import Test.Tasty
import Test.Tasty.Hspec
import Text.Trifecta

import Language.Python.Parser.Indentation

resultShouldBe :: (HasCallStack, Show a, Eq a) => Result a -> a -> Expectation
resultShouldBe supplied exemplar =
  case supplied of
    Success a -> a `shouldBe` exemplar
    Failure e ->
      expectationFailure $ unlines
      [ "Expected successful parse of: " <> show exemplar <> ","
      , "but got an error:"
      , ""
      , show $ _errDoc e
      ]

shouldFail :: (Show a, HasCallStack) => Result a -> Expectation
shouldFail res =
  case res of
    Success _ ->
      expectationFailure $ unlines
      [ "Expected failed parse, but got an success:"
      , ""
      , show res
      ]
    Failure _ -> shouldBe () ()

indentationParse :: IndentationParserT Parser a -> String -> Result a
indentationParse m =
  parseString (runIndentationParserT m $ 0 :| []) mempty

funcDefParser :: IndentationParsing m => m ()
funcDefParser = do
  string "def funcName():\n"
  indented $ do
    absolute $ string "foo\n"
    absolute $ string "bar\n"
    absolute $ string "baz"
  pure ()

indentationSpec :: Spec
indentationSpec =
  describe "funcDefParser" $ do
    it "succeeds" $ do
      indentationParse funcDefParser (unlines
        [ "def funcName():"
        , " foo"
        , " bar"
        , " baz"
        ]) `resultShouldBe` ()
      indentationParse funcDefParser (unlines
        [ "def funcName():"
        , "   foo"
        , "   bar"
        , "   baz"
        ]) `resultShouldBe` ()
      indentationParse funcDefParser (unlines
        [ "def funcName():"
        , "\tfoo"
        , "\tbar"
        , "\tbaz"
        ]) `resultShouldBe` ()
    it "fails" $ do
      shouldFail $
        indentationParse funcDefParser (unlines
        [ "def funcName():"
        , " foo"
        , "  bar"
        , " baz"
        ])
      shouldFail $
        indentationParse funcDefParser (unlines
        [ "def funcName():"
        , "   foo"
        , "  bar"
        , "   baz"
        ])
      shouldFail $
        indentationParse funcDefParser (unlines
        [ "def funcName():"
        , "\tfoo"
        , "\t\tbar"
        , "\tbaz"
        ])
      shouldFail $
        indentationParse funcDefParser (unlines
        [ "def funcName():"
        , "foo"
        , "bar"
        , "baz"
        ])

makeIndentationTests :: IO [TestTree]
makeIndentationTests = testSpecs indentationSpec
