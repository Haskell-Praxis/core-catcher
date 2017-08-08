{-# LANGUAGE ConstrainedClassMethods #-}
{-# LANGUAGE FlexibleContexts        #-}
{-# LANGUAGE NamedFieldPuns          #-}
{-# LANGUAGE NoImplicitPrelude       #-}
{-# LANGUAGE OverloadedStrings       #-}
{-# LANGUAGE ScopedTypeVariables     #-}
{-# LANGUAGE TypeFamilies            #-}

{-
This module implements functions managing Client Connections inside a bigger state-type.

The state-type has to be kept within an TVar variable and the update functions are done using IO

For instances, it is only necessary to TODO

Note: this is used for preventing mutually recursive modules.

TODO: write about what is exported and how to use this module
-}

module App.ConnectionMgnt (
    ConnectionId,
    ClientConnection(..),
    ClientConnections(..),
    HasConnections,
    Conn,
    connectClient,
    disconnectClient,
    getConnections,
    setConnections,
    findConnectionById,
    withoutClient,
    IsConnection,
    Pending,
    sendMsg,
    sendSendableMsg,
    recvMsg,
    acceptRequest,
    multicastMsg
    ) where

import           ClassyPrelude
import           Network.Protocol

type ConnectionId = Int
data ClientConnection conn =
    ClientConnection
        { connectionId :: ConnectionId
        , connection   :: conn
        }

data ClientConnections conn =
    ClientConnections
        { connections :: Seq (ClientConnection conn)
        , nextId :: ConnectionId
        }

class IsConnection c where
    type Pending c :: *

    sendMsg :: c -> MessageForClient -> IO ()

    recvMsg :: c -> IO (Maybe MessageForServer)

    sendSendableMsg :: SendableToClient msg => c -> msg -> IO ()
    sendSendableMsg c msg = sendMsg c $ wrap msg

    acceptRequest ::  Pending c -> IO c

    -- TODO: optimal multicast signature if ClientConnections was MonoFoldable
--     multicastMsg ::
--         (SendableToClient msg, MonoFoldable f, IsConnection c, c ~ Element f)
--         => f -> msg -> IO ()
    multicastMsg :: (SendableToClient msg) => ClientConnections c -> msg -> IO ()
    multicastMsg cs msg = omapM_ (`sendSendableMsg` msg) $ connections cs

-- instance for the ClientConnection type which is just clientId together with
instance IsConnection conn => IsConnection (ClientConnection conn) where
    type Pending (ClientConnection conn) = (ConnectionId, Pending conn)

    sendMsg ClientConnection {connection} = sendMsg connection

    recvMsg ClientConnection {connection} = recvMsg connection

    acceptRequest (cId, pending) = do
        c <- acceptRequest pending
        return $ ClientConnection cId c



class HasConnections state where
    type Conn state :: *

    getConnections :: state -> ClientConnections (Conn state)

    setConnections :: ClientConnections (Conn state) -> state -> state

    connectClient :: Conn state -> TVar state -> IO ConnectionId
    connectClient conn stateVar = do
        clientId <- atomically $ addClient conn stateVar
        putStrLn $ "connect " ++ tshow clientId
        return clientId

    disconnectClient :: ConnectionId -> TVar state -> IO ()
    disconnectClient clientId stateVar = do
        atomically $ removeClient clientId stateVar
        putStrLn $ "disconnect " ++ tshow clientId

-- implement HasConnections for ClientConnections themselves
instance IsConnection conn => HasConnections (ClientConnections conn) where
    type Conn (ClientConnections conn) = conn
    getConnections = id
    setConnections = const

-- extra functions

findConnectionById :: ConnectionId -> ClientConnections conn -> Maybe (ClientConnection conn)
findConnectionById cId =
    find ((==cId) . connectionId) . connections

withoutClient :: ConnectionId -> ClientConnections conn -> ClientConnections conn
withoutClient cId conns =
    conns
        { connections = filter ((/=cId) . connectionId) . connections $ conns
        }

-- helper functions (not exported)

-- TODO: maybe acceptClient instead of addClient??
addClient :: HasConnections state => Conn state -> TVar state -> STM ConnectionId
addClient conn stateVar = do -- update connection list
    state <- readTVar stateVar
    let conns = getConnections state
    let newConnections =
            conns
                { connections =
                    ClientConnection (nextId conns) conn
                    `cons`
                    connections conns
                , nextId = 1 + nextId conns
                }

    writeTVar stateVar (setConnections newConnections state)
    return $ nextId conns

removeClient :: HasConnections state => ConnectionId -> TVar state -> STM ()
removeClient cId stateVar = do
    state <- readTVar stateVar
    let connections = getConnections state
    writeTVar stateVar (setConnections (withoutClient cId connections) state)


-- TODO: instance MonoFoldable & MonoTraversable for ClientConnections