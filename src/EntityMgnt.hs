{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NamedFieldPuns        #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE Rank2Types            #-}
{-# LANGUAGE TypeFamilies          #-}

-- TODO: remake comment
-- TODO: test

module EntityMgnt where

import           ClassyPrelude
import           Control.Monad.State

-- TODO: instance MonoFoldable & MonoTraversable for e
data Entities i e =
    Entities
        { entities :: Map i e
        , nextId   :: i
        }

emptyEntities :: EntityId i => Entities i e
emptyEntities =
    Entities
        { entities = mempty
        , nextId = getFirstId
        }

class Ord i => EntityId i where
    getFirstId :: i
    getNextId :: i -> i

instance EntityId Int where
    getFirstId = 0
    getNextId = (+1)

class EntityId i => HasEntities container i where
    type Entity container i :: *

    getEntities :: container -> Entities i (Entity container i)

    setEntities :: Entities i (Entity container i) -> container -> container

    entityMap :: container -> Map i (Entity container i)
    entityMap = entities . getEntities

    entityAssocs :: container -> [(i, Entity container i)]
    entityAssocs = mapToList . entityMap

    findEntityById :: i -> container -> Maybe (Entity container i)
    findEntityById gId =
        lookup gId . entities . getEntities

    -- |add an entity with the next id. The given id is returned.
    addEntity :: Entity container i -> container -> (i, container)
    addEntity entity container =
        let
            es@Entities{entities, nextId} = getEntities container
            newEntities =
                es
                    { entities =
                        insertMap nextId entity entities
                    , nextId = getNextId nextId
                    }
        in
            ( nextId
            , setEntities newEntities container
            )


    -- |set an entity value. The entity should already exist in the map.
    updateEntity :: i -> Entity container i -> container -> container
    updateEntity eId entity container =
        let
            es@Entities{entities} = getEntities container
            newEntities =
                es
                    { entities =
                        insertMap eId entity entities
                    }
        in
            setEntities newEntities container

    -- |Modifies an entity according to a given function.
    modifyEntity :: i -> (Entity container i -> Entity container i) -> container -> container
    modifyEntity eId f container =
        let
            es@Entities{entities} = getEntities container
            newEntities = case findEntityById eId container of
                Nothing -> es
                Just e ->
                    es
                        { entities =
                            insertMap eId (f e) entities
                        }
        in
            setEntities newEntities container

    -- |Remove an entity from the map and return the assigned connection
    removeEntity :: i -> container -> container
    removeEntity eId container =
        let
            es@Entities{entities} = getEntities container
            newMap = deleteMap eId entities
            newEntities = es { entities = newMap }
        in
            setEntities newEntities container

    -- |Method for retrieving all entites
    allEntities :: container -> [(i, Entity container i)]
    allEntities = mapToList . entities . getEntities

-- implement HasEntities for Entities themselves
instance EntityId i => HasEntities (Entities i e) i where
    type Entity (Entities i e) i = e
    getEntities = id
    setEntities = flip const

instance (Show i, Show e) => Show (Entities i e) where
    show = show . entities

-- Entity methods for stateT monad

addEntityS
    :: (MonadState m, StateType m ~ state, HasEntities state i)
    => Entity state i -> m i
addEntityS newEntity = do
    state <- get
    let (eId, newState) = addEntity newEntity state
    put newState
    return eId

updateEntityS
    :: (MonadState m, StateType m ~ state, HasEntities state i)
    => i -> Entity state i -> m ()
updateEntityS eId newEntity = modify $ updateEntity eId newEntity

modifyEntityS
    :: (MonadState m, StateType m ~ state, HasEntities state i)
    => i -> (Entity state i -> Entity state i) -> m ()
modifyEntityS eId f = modify $ modifyEntity eId f

removeEntityS :: (MonadState m, StateType m ~ state, HasEntities state i) => i -> m ()
removeEntityS eId = modify $ removeEntity eId

findEntityByIdS
    :: (MonadState m, StateType m ~ state, HasEntities state i)
    => i
    -> m (Maybe (Entity state i))
findEntityByIdS = gets . findEntityById
