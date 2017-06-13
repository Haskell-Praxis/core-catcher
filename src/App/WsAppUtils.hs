{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module App.WsAppUtils where

import           App.Connection
import           App.ConnectionMgnt
import           ClassyPrelude
import qualified Data.Aeson         as Aeson
import           Network.Protocol

sendView :: IsConnection conn => ClientConnection conn -> GameView -> IO ()
sendView ci view =
    sendData (snd ci) (Aeson.encode view)

sendRogueView :: IsConnection conn => ClientConnection conn -> RogueGameView -> IO ()
sendRogueView ci view =
    sendView ci $ RogueView view

sendCatcherView :: IsConnection conn => ClientConnection conn -> CatcherGameView -> IO ()
sendCatcherView ci view =
    sendView ci $ CatcherView view

sendError :: IsConnection conn => ClientConnection conn -> GameError -> IO ()
sendError ci err =
    sendData (snd ci) (Aeson.encode err)

recvAction :: IsConnection conn => ClientConnection conn -> IO (Maybe Action)
recvAction (_,ws) = do
    wsData <- receiveData ws
    return (Aeson.decode wsData)

broadcastCatcherView :: IsConnection conn => ClientConnections conn -> CatcherGameView -> IO ()
broadcastCatcherView conns view =
    mapM_ (\conn -> sendCatcherView conn view) conns

withoutClient :: ClientId -> ClientConnections conn -> ClientConnections conn
withoutClient cid =
    filter ((cid /=) . fst)
