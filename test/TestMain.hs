{-# LANGUAGE NoImplicitPrelude #-}
{-# OPTIONS_GHC -F -pgmF htfpp #-}

import           ClassyPrelude

import           Test.Framework

import {-@ HTF_TESTS @-} ProtocolTest
import {-@ HTF_TESTS @-} MainTest
import {-@ HTF_TESTS @-} StateTest
import {-@ HTF_TESTS @-} WsAppUtilsTest
import {-@ HTF_TESTS @-} GameNgTest

main :: IO ()
main = do
    args <- getCurrentArgs
    setDefaultArgs (args { maxSuccess = 15 } ) 
    htfMain htf_importedTests
