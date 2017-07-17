{-# LANGUAGE DeriveAnyClass    #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}
{-# LANGUAGE TypeFamilies      #-}

-- Text has no arbitrary instance, defined here
{-# OPTIONS_GHC -Wno-orphans #-}

module Network.Protocol where

import           ClassyPrelude
import           Data.Aeson                as Aeson
import           Elm.Derive
import           GHC.Generics              ()
import           Test.QuickCheck.Arbitrary
import qualified Test.QuickCheck.Gen       as Gen
{-
This module provides data-types that are sent to game-clients and bots as messages.
This class is a semantic protocol definition. The data-types are sent in json format.
-}

-- |Players and Nodes are Ints (=Ids). The rouge-player has id 0
newtype Player =
    Player { playerId :: Int }
    deriving (Show, Read, Eq, Ord, Generic)

-- |Node representation
newtype Node =
    Node { nodeId :: Int }
    deriving (Show, Read, Eq, Ord, Generic)

-- |Edge is a tuple of two Nodes
newtype Edge =
    Edge { edge :: (Node, Node) }
    deriving (Show, Read, Eq, Ord, Generic)

-- TODO: rename transport to energy??
-- |Transport is a text
newtype Transport =
    Transport { transportName :: Text }
    deriving (Show, Read, Eq, Ord, Generic)

{- |A engergy-map is keeps track how much energy per transport a player has left.
-}
newtype EnergyMap =
    EnergyMap
        { energyMap :: Map Transport Int
        }
        deriving (Show, Read, Eq, Generic)

newtype GameError =
    GameError
        { myError :: Text
        }
        deriving (Show, Read, Eq, Generic)

{- |The playerEnergies Map keeps track of the EnergyMaps for all players.
-}
newtype PlayerEnergies =
    PlayerEnergies
        { playerEnergies :: Map Player EnergyMap
        }
        deriving (Show, Read, Eq, Generic)

{- |An action is something one of the players can do.
Currently this is only a move, but this may be expanded in the future.
-} -- TODO: write into design document that an action is more than a move. Maybe change?
data Action =
    Move
      { actionPlayer    :: Player
      , actionTransport :: Transport
      , actionNode      :: Node
      }
    deriving (Show, Read, Eq, Generic)

{- |The playerPositions map keeps track of the current nodes each player is on.

It is possible that the map is not complete.
This should be the case if the missing player should not be seen.
-}
newtype PlayerPositions =
    PlayerPositions
        { playerPositions :: Map Player Node -- ^player 0 is the rogue core
        }
    deriving (Show, Read, Eq, Generic)

{- |The history of transports used by the rouge core.
-} -- TODO: Seq instead of list?
newtype RogueHistory =
    RogueHistory
        { rogueHistory :: [(Transport, Maybe Node)]
        }
      deriving (Show, Read, Eq, Generic)

{- |A game view as seen by the rouge-core.
-}
data RogueGameView =
    RogueGameView
        { roguePlayerPositions :: PlayerPositions
        , rogueEnergies        :: PlayerEnergies
        , rogueOwnHistory      :: RogueHistory
        , rogueNextPlayer      :: Player
        }
        deriving (Show, Read,  Eq, Generic)

{- |A game view as seen by the catchers
-}
data CatcherGameView =
    CatcherGameView
        { catcherPlayerPositions :: PlayerPositions
        , catcherEnergies        :: PlayerEnergies
        , catcherRogueHistory    :: RogueHistory
        , catcherNextPlayer      :: Player
        }
        deriving (Show, Read, Eq, Generic)

{- |A game view is a subset of the game-State as seen by one of the players.
A game view should be determined by the player it is constructed for and a game state.
GameView is glue code for the game state. No actual game state is sent between
the fronend and the backend but only the views.
Views can contain different information based on the receiver.
-}
data GameView =
    RogueView RogueGameView | CatcherView CatcherGameView
    deriving (Show, Read,  Eq, Generic)

viewPlayerPositions :: GameView -> PlayerPositions
viewPlayerPositions (CatcherView view) = catcherPlayerPositions view
viewPlayerPositions (RogueView view)   = roguePlayerPositions view

viewEnergies :: GameView -> PlayerEnergies
viewEnergies (CatcherView view) = catcherEnergies view
viewEnergies (RogueView view)   = rogueEnergies view

viewRogueHistory :: GameView -> RogueHistory
viewRogueHistory (CatcherView view) = catcherRogueHistory view
viewRogueHistory (RogueView view)   = rogueOwnHistory view

viewNextPlayer :: GameView -> Player
viewNextPlayer (CatcherView view) = catcherNextPlayer view
viewNextPlayer (RogueView view)   = rogueNextPlayer view

{- |Network: Nodes and Map Transport to Overlay.

The overlays contain the actual Edges

The network itself has no information about its representation.
Representation is handled via NetworkDisplayInfo

-}
data Network =
    Network
        { nodes    :: [Node]
        , overlays :: Map Transport NetworkOverlay
        }
        deriving (Show, Read, Eq, Generic)


{- |NetworkOverlay: Sub-Graph that contains several nodes

-}
data NetworkOverlay =
    NetworkOverlay
        { overlayNodes :: [Node] -- ^the contained nodes in the Overlay.
        , overlayEdges :: [Edge] -- ^The edges must only connect the nodes contained in the first list.
        }
        deriving (Show, Read, Eq, Generic)

{- | InitialDataForClient the initial info the client gets

-}
data InitialInfoForClient =
    InitialInfoForClient
        { initialPlayer   :: Player
        , networkForGame  :: Network
        , initialGameView :: GameView
        }
        deriving (Show, Read, Eq, Generic)

data MessageForServer =
    Action_ Action
    deriving (Show, Read, Eq, Generic)

data MessageForClient =
    GameView_ GameView |
    InitialInfoForClient_ InitialInfoForClient
    deriving (Show, Read, Eq, Generic)

instance FromJSONKey Player where

instance FromJSONKey Node where

instance FromJSONKey Transport where

instance ToJSONKey Player where

instance ToJSONKey Transport where

instance Arbitrary Text where
    arbitrary = pack <$> arbitrary

instance Arbitrary Player  where
    arbitrary =
        Player <$> arbitrary

instance Arbitrary Node  where
    arbitrary =
        Node <$> arbitrary

instance Arbitrary Edge  where
    arbitrary =
        Edge <$> ((,) <$> arbitrary <*> arbitrary)

instance Arbitrary Transport  where
    arbitrary =
        Transport <$> arbitrary

instance Arbitrary Action where
    arbitrary =
        Move <$> arbitrary <*> arbitrary <*> arbitrary

instance Arbitrary PlayerPositions where
    arbitrary =
        PlayerPositions <$> arbitrary

instance Arbitrary PlayerEnergies where
    arbitrary =
        PlayerEnergies <$> arbitrary

instance Arbitrary EnergyMap where
    arbitrary =
        EnergyMap <$> arbitrary

instance Arbitrary RogueHistory where
    arbitrary =
        RogueHistory <$> arbitrary

instance Arbitrary GameError where
    arbitrary =
        GameError <$> (arbitrary :: Gen.Gen Text)

instance Arbitrary CatcherGameView where
    arbitrary =
        CatcherGameView <$> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary

instance Arbitrary RogueGameView where
    arbitrary =
        RogueGameView <$> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary

instance Arbitrary Network where
    arbitrary =
        Network <$> arbitrary <*> arbitrary

instance Arbitrary NetworkOverlay where
    arbitrary =
        NetworkOverlay <$> arbitrary <*> arbitrary

instance Arbitrary GameView where
    arbitrary = do
        rogue <- arbitrary
        if rogue then
            RogueView <$> arbitrary
        else
            CatcherView <$> arbitrary

deriveBoth Elm.Derive.defaultOptions ''Action
deriveBoth Elm.Derive.defaultOptions ''PlayerPositions
deriveBoth Elm.Derive.defaultOptions ''GameView
deriveBoth Elm.Derive.defaultOptions ''RogueGameView
deriveBoth Elm.Derive.defaultOptions ''CatcherGameView
deriveBoth Elm.Derive.defaultOptions ''GameError
deriveBoth Elm.Derive.defaultOptions ''PlayerEnergies
deriveBoth Elm.Derive.defaultOptions ''EnergyMap
deriveBoth Elm.Derive.defaultOptions ''Network
deriveBoth Elm.Derive.defaultOptions ''NetworkOverlay
deriveBoth Elm.Derive.defaultOptions ''Player
deriveBoth Elm.Derive.defaultOptions ''Edge
deriveBoth Elm.Derive.defaultOptions ''Node
deriveBoth Elm.Derive.defaultOptions ''Transport
deriveBoth Elm.Derive.defaultOptions ''RogueHistory
deriveBoth Elm.Derive.defaultOptions ''InitialInfoForClient
deriveBoth Elm.Derive.defaultOptions ''MessageForServer
deriveBoth Elm.Derive.defaultOptions ''MessageForClient

type instance Element PlayerPositions = Node

instance Monoid PlayerPositions where
    mempty = PlayerPositions mempty
    mappend pp1 pp2 = PlayerPositions $ playerPositions pp1 ++ playerPositions pp2

instance MonoFunctor PlayerPositions where
    omap f = PlayerPositions . omap f . playerPositions

instance MonoFoldable PlayerPositions where
    ofoldMap f = ofoldMap f . playerPositions
    ofoldr f x = ofoldr f x . playerPositions
    ofoldl' f x = ofoldl' f x . playerPositions
    olength = olength . playerPositions
    olength64 = olength64 . playerPositions
    ofoldr1Ex f = ofoldr1Ex f . playerPositions
    ofoldl1Ex' f = ofoldl1Ex' f . playerPositions

instance MonoTraversable PlayerPositions where
    otraverse f = map PlayerPositions . otraverse f . playerPositions

instance Semigroup PlayerPositions where
instance GrowingAppend PlayerPositions where


instance SetContainer PlayerPositions where
    type ContainerKey PlayerPositions = Player
    member p = member p . playerPositions
    notMember p = notMember p . playerPositions
    union pp1 pp2 = PlayerPositions $ union (playerPositions pp1) (playerPositions pp2)
    difference pp1 pp2 = PlayerPositions $ difference (playerPositions pp1) (playerPositions pp2)
    intersection pp1 pp2 = PlayerPositions $ intersection (playerPositions pp1) (playerPositions pp2)
    keys = keys . playerPositions


instance IsMap PlayerPositions where
    type MapValue PlayerPositions = Node
    lookup k = lookup k . playerPositions
    insertMap k v = PlayerPositions . insertMap k v . playerPositions
    deleteMap k = PlayerPositions . deleteMap k . playerPositions
    singletonMap k v = PlayerPositions $ singletonMap k v
    mapFromList = PlayerPositions . mapFromList
    mapToList = mapToList . playerPositions
