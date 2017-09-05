{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

{-
code taken from tutorial
https://www.paramander.com/blog/playing-with-websockets-in-haskell-and-elm
and code from
https://gitlab.com/paramander/typesafe-websockets/blob/master/src/Main.hs
-}

module Main where

import           App.ConnectionMgnt
import           App.State
import           App.WsApp
import           ClassyPrelude                  hiding (handle)
import qualified Config.GameConfig              as GameConfig
import qualified Control.Exception              as Exception
import qualified GameNg
import qualified Network.Wai                    as Wai
import qualified Network.Wai.Application.Static as WaiStatic
import qualified Network.Wai.Handler.Warp       as Warp
import qualified Network.Wai.Handler.WebSockets as WS
import qualified Network.WebSockets             as WS
import           WsConnection

main :: IO ()
main = do
    stateVar <- newTVarIO ServerState
        { stateConnections = ClientConnections empty 0
        -- TODO: improve game-state creation
        , gameState = GameNg.GameRunning_ $ GameNg.initialState GameConfig.defaultConfig
        }
    putStrLn "Starting Core-Catcher server on port 8000"

    Warp.run 8000 $ WS.websocketsOr
        WS.defaultConnectionOptions
        (wsApp stateVar)
        httpApp

httpApp :: Wai.Application
httpApp = WaiStatic.staticApp (WaiStatic.defaultFileServerSettings "web")


wsApp :: TVar (ServerState WsConnection) -> WS.ServerApp
wsApp stateVar pendingConn = do
    conn <- WS.acceptRequest pendingConn
    let wsConn = WsConnection conn
    WS.forkPingThread conn 30
    cId <- connectClient wsConn stateVar -- call to ConnectionMgnt
    let clientConn = ClientConnection cId wsConn
    -- TODO: handshake first
    sendSendableMsg clientConn $
        initialInfoForClient GameConfig.defaultConfig cId
    Exception.finally
        (wsListen clientConn stateVar)
        (disconnectClient cId stateVar) -- call to ConnectionMgnt

wsListen :: IsConnection conn => ClientConnection conn -> TVar (ServerState conn) -> IO ()
wsListen client stateVar = forever $ do
    maybeMsg <- recvMsg client
    case maybeMsg of
        Just msg -> do
            -- TODO: what about request forging? (send game-token to client using player-mgnt)
            -- TODO: validation playerId==clientId
            handle client stateVar msg
            return ()

        Nothing     ->
            putStrLn "ERROR: The message could not be decoded"
            -- TODO: send info back to client?
