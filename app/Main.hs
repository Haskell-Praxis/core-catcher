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
import qualified App.WsApp                      as WsApp
import qualified App.WsAppUtils                 as WsAppUtils
import           ClassyPrelude
import qualified Control.Exception              as Exception
import qualified Glue
--import qualified Network.ExampleGameView        as Example
import qualified Network.ElmDerive              as ElmDerive
import qualified Network.HTTP.Types             as Http
import qualified Network.Wai                    as Wai
import qualified Network.Wai.Handler.Warp       as Warp
import qualified Network.Wai.Handler.WebSockets as WS
import qualified Network.WebSockets             as WS

main :: IO ()
main = do
    writeFileUtf8 "frontend/Protocol.elm" ElmDerive.elmProtocolModule
    putStrLn "Starting Core-Catcher server on port 3000"
    Warp.run 3000 $ WS.websocketsOr
        WS.defaultConnectionOptions
        wsApp
        httpApp

httpApp :: Wai.Application
httpApp _ respond = respond $ Wai.responseLBS Http.status400 [] "Not a websocket request"


wsApp :: WS.ServerApp
wsApp pendingConn = do -- TODO: fixme: new state for every connection...
    stateVar <- newTVarIO ServerState {connections = empty, gameState = Glue.initialState } -- TODO: insert GL.GameState instead
    conn <- WS.acceptRequest pendingConn
    let gameConn = GameConnection conn
    clientId <- connectClient gameConn stateVar -- call to ConnectionMgnt
    WS.forkPingThread conn 30
    Exception.finally
        (wsListen (clientId, gameConn) stateVar)
        (disconnectClient clientId stateVar) -- call to ConnectionMgnt

wsListen :: IsConnection conn => ClientConnection conn -> TVar (ServerState conn) -> IO ()
wsListen client stateVar = forever $ do
    maybeAction <- WsAppUtils.recvAction client
    case maybeAction of
        Just action -> do
            -- TODO: what about request forging?
            -- TODO: validation playerId==clientId
            WsApp.handle stateVar action
            return ()

        Nothing     ->
            putStrLn "ERROR: The message could not be decoded"
