{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -F -pgmF htfpp #-}

module GameNgTest where

import           ClassyPrelude
import           Data.Map.Strict  (insert)
import           GameNg
import           Network.Protocol
import           Test.Framework
import           Test.HUnit.Base

-- (@?=) = assertEqual
test_initialStateHasStartingPlayer0 :: IO ()
test_initialStateHasStartingPlayer0 = Player 0 @?= stateNextPlayer initialState

test_initialStateHasEmptyHistory :: IO ()
test_initialStateHasEmptyHistory =
    RogueHistory [] @?= stateRogueHistory initialState

test_player0ValidMove :: IO ()
test_player0ValidMove =
    case updateState (Move (Player 0) (Transport "red") (Node 6)) initialState of
        Left (GameError err) -> assertFailure . unpack $ "action failed: " ++ err
        Right (newState, _, _) ->
            (insert (Player 0) (Node 6) . playerPositions . statePlayerPositions $
             initialState) @?=
            (playerPositions . statePlayerPositions $ newState)

test_notPlayer1Turn :: IO ()
test_notPlayer1Turn =
    case updateState (Move (Player 1) (Transport "yellow") (Node 5)) initialState of
        Left (GameError err) ->
            unless ("turn" `isInfixOf` err) $
            assertFailure $ "wrong error msg: " ++ unpack err
        Right _              -> assertFailure "should not be player 1's turn"

{- error message is that its not player's turn and not 'player not found'
test_playerNotFound :: IO ()
test_playerNotFound =
    case updateState (Move (Player (-1)) (Transport "yellow") (Node 5)) initialState of
        Left (GameError err) ->
            unless ("not found" `isInfixOf` err) $
            assertFailure $ "wrong error msg: " ++ unpack err
        Right _              -> assertFailure "should not find player"
-}

test_energyNotFound :: IO ()
test_energyNotFound =
    case updateState (Move (Player 0) (Transport "green") (Node 5)) initialState of
        Left (GameError err) ->
            unless ("not found" `isInfixOf` err) $
            assertFailure $ "wrong error msg: " ++ unpack err
        Right _              -> assertFailure "should not find energy"

test_cannotMoveTo :: IO ()
test_cannotMoveTo =
    case updateState (Move (Player 0) (Transport "orange") (Node 1)) initialState of
        Left (GameError err) ->
            unless ("node" `isInfixOf` err) $
            assertFailure $ "wrong error msg: " ++ unpack err
        Right _              -> assertFailure "should not be allowed to move"

test_noEnergyLeft :: IO ()
test_noEnergyLeft =
    case updateState (Move (Player 0) (Transport "yellow") (Node 6)) noEnergyState of
        Left _  -> return ()
        Right _ -> assertFailure "should not allow move with no energy"
    where
        noEnergyState =
            initialState
                { statePlayerEnergies =
                    PlayerEnergies $
                        singletonMap (Player 0) (EnergyMap $ singletonMap (Transport "yellow") 0)
                }

-- TODO: test energy consumption, test more rounds
