{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -F -pgmF htfpp #-}

{- |Module for testing the app module.

The main function to execute test cases is the gameNgTestCase function defined in this module.
TODO: fix documentation

TODO: fix tests with new app interface

-}
module AppTest where

import           App.App
import           App.AppUtils
import           App.ConnectionState
import           App.State
import           ClassyPrelude              hiding (handle)
import           Config.GameConfig          (GameConfig (..), defaultConfig)
import           Control.Monad.State        (runState)
import qualified Control.Monad.State        as State
import           Control.Monad.Trans.Except
import           Data.Easy                  (tripleToPair)
import           Data.Maybe                 (fromJust)
import           EntityMgnt
import           Mock.Connection
import           Network.Protocol
import           System.Random              (RandomGen, mkStdGen)
import qualified System.Random              as Random
import           Test.Framework
import           Test.HUnit.Base



test_loginRogue_initialInfo :: IO ()
test_loginRogue_initialInfo =
    appTestCase
        initialStateWith3Connections
        [(ConnectionId 0, Login_ . Login $ alice)]
        assertions
    where
        assertions (msgs, _) = do
            [ConnectionId 0] @?= map fst msgs
            case snd . headEx $ msgs of
                PlayerHome_ _ ->return ()
                msg ->
                    assertFailure $
                        "should have sent PlayerHome to alice, but sent "
                        ++ show msg

-- TODO: reuse assertions for other cases
--         assertions state = do
--             msgSent <- getSentMsg $ getConnectionById 0 state
--             case msgSent of
--                 Nothing -> assertFailure "should have sent initial info to alice"
--                 Just (InitialInfoGameActive_ InitialInfoGameActive
--                     { initialPlayer
--                     , initialGameView
--                     , networkForGame
--                     , allPlayers
--                     , allEnergies
--                     }) -> do
--                     -- assertions on all fields of the initialInfoForClient
--                     alice @?= initialPlayer
--                     network defaultConfig @?= networkForGame
--                     [alice, bob, charlie] @?= allPlayers
--                     [Red, Blue, Orange] @?= allEnergies
--                     case initialGameView of
--                         CatcherView _ -> assertFailure "expeced rogue view"
--                         RogueView _   -> return ()
--
--                 Just msg -> assertFailure $ "expected initialInfo, got " ++ show msg
--
-- test_loginCatcher_initialInfo :: IO ()
-- test_loginCatcher_initialInfo = do
--     stateVar <- initialStateWith3FakeConnections
--     appTestCase
--         stateVar
--         [(1,Login_ . Login $ bob)]
--         assertions
--     where
--         assertions state = do
--             msgSent <- getSentMsg $ getConnectionById 1 state
--             case msgSent of
--                 Nothing -> assertFailure "should have sent to bob"
--                 Just (InitialInfoGameActive_ info) -> do
--                     bob @?= initialPlayer info
--                     network defaultConfig @?= networkForGame info
--                 Just msg -> assertFailure $ "expected initialInfo, got " ++ show msg
--
--
-- test_playerMoved_responseToAllWithCorrectGameView :: IO ()
-- test_playerMoved_responseToAllWithCorrectGameView = do
--     stateVar <- initialStateWith3Logins
--     appTestCase
--         stateVar
--         [(0, Action_ $ Move alice Red (Node 6))]
--         assertions
--     where
--         assertions state = do
--             -- assertion for rogue
--             msgSentToRogue <- getSentMsg $ getConnectionById 0 state
--             case msgSentToRogue of
--                 Nothing ->
--                     assertFailure "should have sent to rogue"
--                 Just (GameView_ (RogueView RogueGameView {rogueNextPlayer})) ->
--                     bob @?= rogueNextPlayer
--                 Just msg ->
--                     assertFailure $ "expected gameView, got " ++ show msg
--             -- assertions for catcher
--             mapM_
--                 (\cId -> do
--                     msgSent <- getSentMsg $ getConnectionById cId state
--                     case msgSent of
--                         Nothing ->
--                             assertFailure $ "should have sent to " ++ show cId
--                         Just (GameView_ (CatcherView CatcherGameView {catcherNextPlayer})) ->
--                             bob @?= catcherNextPlayer
--                         Just msg ->
--                             assertFailure $ "expected gameView, got " ++ show msg
--                 )
--                 [1,2]
--
-- test_playerMovedIncorrectly_gameErrorToOnlyOne :: IO ()
-- test_playerMovedIncorrectly_gameErrorToOnlyOne = do
--     stateVar <- initialStateWith3Logins
--     appTestCase
--         stateVar
--         [(1, Action_ $ Move bob Red (Node 6))]
--         assertions
--     where
--         assertions state = do
--             msgSentToBob <- getSentMsg $ getConnectionById 1 state
--             case msgSentToBob of
--                 Nothing -> assertFailure "should have sent gameError to bob"
--                 Just (GameError_ err) ->
--                     NotTurn alice @?= err
--                 Just msg -> assertFailure $ "expected gameError, got " ++ show msg
--
--             mapM_
--                 (\cId -> do
--                     msgSent <- getSentMsg $ getConnectionById cId state
--                     Nothing @?= msgSent
--                 )
--                 [0,2]
--
--
-- test_playerMovedIncorrectly_stateSillOld :: IO ()
-- test_playerMovedIncorrectly_stateSillOld = do
--     stateVar <- initialStateWith3Logins
--     appTestCase
--         stateVar
--         [ (1, Action_ $ Move bob Red (Node 6))
--         , (0, Action_ $ Move alice Red (Node 6))]
--         assertions
--     where
--         assertions state = do
--             -- test that alice did move indeed
--             msgSentToAlice <- getSentMsg $ getConnectionById 0 state
--             case msgSentToAlice of
--                 Nothing -> assertFailure "should have sent to rogue"
--                 Just (GameView_ _) -> return ()
--                 Just msg -> assertFailure $ "expected gameView, got " ++ show msg
--
--
-- test_playerMovedCorrectly_stateUpdatedTwice :: IO ()
-- test_playerMovedCorrectly_stateUpdatedTwice = do
--     stateVar <- initialStateWith3Logins
--     appTestCase
--         stateVar
--         [ (0, Action_ $ Move alice Red (Node 6))
--         , (1, Action_ $ Move bob Orange (Node 10))
--         ]
--         assertions
--     where
--         assertions state = do
--             -- test that alice did move indeed
--             -- TODO: test that 2 messages have been sent?
--             msgSentToAlice <- getSentMsg $ getConnectionById 0 state
--             case msgSentToAlice of
--                 Nothing -> assertFailure "should have sent to rogue"
--                 Just (GameView_ (RogueView RogueGameView {rogueNextPlayer})) ->
--                     charlie @?= rogueNextPlayer
--                 Just msg -> assertFailure $ "expected gameView, got " ++ show msg
--

-- TODO: tests for gameOver

{- |Function for testing the app-module.

A test case consists of preparation, execution and assertions.
In this case, the preparation is done in the configuration, the execution consists of actions to execute and
the assertions evaluate the result.

-}
appTestCase
    :: ServerState conn
    -> [(ConnectionId, MessageForServer)]
    -> (([(ConnectionId, MessageForClient)], ServerState conn) -> IO ())
    -> IO ()
appTestCase initialState msgs assertions =
    assertions $ handleMultipleMsgs (mkStdGen 42) initialState msgs

-- |Helper functions to handle multiple messages
handleMultipleMsgs
    :: RandomGen gen
    => gen
    -> ServerState conn
    -> [(ConnectionId, MessageForServer)]
    -> ([(ConnectionId, MessageForClient)], ServerState conn)
handleMultipleMsgs gen initialState =
    tripleToPair . foldl' foldF ([], initialState, gen)
    where
        foldF
            :: RandomGen gen
            => ([(ConnectionId, MessageForClient)], ServerState conn, gen)
            -> (ConnectionId, MessageForServer)
            -> ([(ConnectionId, MessageForClient)], ServerState conn, gen)
        foldF (clientMsg, state, gen) (cId,msg) =
            let
                (g1, g2) = Random.split gen
                (newClientMsgs, newState) = handleOneMsg g1 cId msg state
            in (clientMsg ++ newClientMsgs, newState, g2)

handleOneMsg
    :: RandomGen gen
    => gen
    -> ConnectionId
    -> MessageForServer
    -> ServerState conn
    -> ([(ConnectionId, MessageForClient)], ServerState conn)
handleOneMsg gen cId msg serverState =
    let (updateResult, newServerState) =
            runState (runExceptT $ handleMsgState gen cId msg) serverState
    in case updateResult of
       Left err ->
           (msgForOne cId $ ServerError_ err, serverState)
       Right toSend ->
           (toSend, newServerState)


initialStateWith3Connections :: ServerState ()
initialStateWith3Connections = State.execState (do
        ConnectionId _ <- addEntityS $ newConnectionInfo ()
        ConnectionId _ <- addEntityS $ newConnectionInfo ()
        ConnectionId _ <- addEntityS $ newConnectionInfo ()
        return ()
    ) defaultInitialState

-- TODO: implement
-- initialStateWith3Logins :: ServerState FakeConnection
-- initialStateWith3Logins = do
--     stateVar <- initialStateWith3FakeConnections
--     handleMultipleMsgs stateVar
--         [ (0, Login_ $ Login alice)
--         , (1, Login_ $ Login bob)
--         , (2, Login_ $ Login charlie)
--         ]
--     state <- readTVarIO stateVar
--     mapM_ (resetSendBuffer . fst . snd) . mapToList . connections . serverStateConnections $ state
--     return stateVar


-- getConnectionById :: ConnectionId -> ServerState FakeConnection -> FakeConnection
-- getConnectionById cId = fst . fromJust . findConnectionById cId

alice :: Player
alice = Player "Alice"

bob :: Player
bob = Player "Bob"

charlie :: Player
charlie = Player "Charlie"
