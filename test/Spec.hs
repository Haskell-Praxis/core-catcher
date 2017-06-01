{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# OPTIONS_GHC -F -pgmF htfpp #-}
import           ClassyPrelude
import           GameLogic      ((>>|))
import           Lib            (mapRight)
import           ProtocolTest
import           Test.Framework
main :: IO ()
main = htfMain htf_thisModulesTests

test_mapRightDoubleValue :: IO ()
test_mapRightDoubleValue =
    let
      x = Right 4 :: Either String Int
      y = Right 8 :: Either String Int
    in
      assertEqual y (mapRight (2*) x)

prop_mapRightWithIdFunction :: Either String Int -> Bool
prop_mapRightWithIdFunction x =
    x == mapRight id x

test_dummy :: IO ()
test_dummy = do
    actual <- (return >>| (\a _ -> return a)) (1 :: Int)
    let expected  = (1,1)
    assertEqual expected actual
