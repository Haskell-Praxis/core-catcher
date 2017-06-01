{-# LANGUAGE NoImplicitPrelude #-}
module Protocol where

import           ClassyPrelude

{-
This module provides data-types that are sent to game-clients and bots as messages.
This class is a semantic protocol definition. The data-types are sent in json format.


-}

-- Players and Nodes are Ints (=Ids). The rouge-player has id 0
type Player = Int
type Node = Int
-- transport is a string
type Transport = String
{-
A engergy-map is keeps track how much energy per transport a player has left.
-}
type EnergyMap = Map Transport Int
{-
The playerEnergies Map keeps track of the EnergyMaps for all players.
-}
type PlayerEnergies = Map Player EnergyMap

{-
An action is something one of the players can do.

Currently this is only a move, but this may be expanded in the future.
-}
data Action =
    Move Player Transport Node
    deriving (Show, Eq)

{-
The playerPositions map keeps track of the current nodes each player is on.

It is possible that the map is not complete.
This should be the case if the missing player should not be seen.
-}
data PlayerPositions =
    Map Player Node -- player 0 is the rogue core

{-
The history of transports used by the rouge core.
-}
type RogueTransportHistory =
    [Transport] -- display infos

{--
data GameState =
    State
        { playerPositions :: PlayerPositions
        , energyMap       :: EnergyMap
        , rogueHistory    :: RogueHistory
        {- ... gamestate fields -}
        }
--}

{-
A game view is a subset of the game-State as seen by one of the players.
A game view should be determined by the player it is constructed for and a game state
-}
class GameView view where
    playerPositions :: view -> PlayerPositions
    energyMap :: view -> EnergyMap
    rogueHistory :: view -> RogueHistory
    rogueLastSeen :: view -> Maybe Node

{-
A game view as seen by the rouge-core
-}
data RogueGameView =
    RogueView
        { roguePlayerPositions :: PlayerPositions
        , rogueEnergyMap       :: PlayerEnergies
        , rogueOwnHistory      :: RogueHistory
        }

{-
A game view as seen by the catchers
-}
data CatcherGameView =
    CatcherView
        { catcherPlayerPositions :: PlayerPositions
        , catcherEenergyMap      :: PlayerEnergies
        , catcherRogueHistory    :: RogueHistory
        , catcherRogueLastSeen   :: Maybe Node
        }

--instance GameView RogueGameView where
