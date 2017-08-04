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
import qualified TH.MonoDerive             as Derive


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

-- |Energy is a enum of possible energies.
data Energy = Red | Blue | Orange
    deriving (Show, Read, Eq, Ord, Generic, Enum, Bounded)

{- |A engergy-map is keeps track how much energy per energy a player has left.
-}
newtype EnergyMap =
    EnergyMap
        { energyMap :: Map Energy Int
        }
        deriving (Show, Read, Eq, Generic)

-- |A GameError is a enum of possible errors
data GameError
    = NotTurn
    | PlayerNotFound Player
    | EnergyNotFound
    | NotReachable
    | NodeBlocked Player
    | NotEnoughEnergy
    | GameIsOver
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
-} -- TODO: write into design document that an action may be more than a move. Maybe change?
data Action =
    Move
        { actionPlayer    :: Player
        , actionEnergy :: Energy
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

-- TODO: Seq instead of list?
-- TODO: rename to shadowRogueHistory?
{- |The history of energies used by the rouge core.
-}
newtype RogueHistory =
    RogueHistory
        { rogueHistory :: [(Energy, Maybe Node)]
        }
    deriving (Show, Read, Eq, Generic)
-- TODO: derive type-classes like monoFunctor, ...

{- |The history of energies used by the rogue together with all nodes

The bool flag indicates whether the node in the history-entry is shown to the catchers
 during the game
-}
newtype OpenRogueHistory =
    OpenRogueHistory
        { openRogueHistory :: [(Energy, Node, Bool)]
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

{- |A view for the game-over screen
-}
data GameOverView =
    GameOverView
        { gameOverViewPlayerPositions :: PlayerPositions
        , gameOverViewEnergies        :: PlayerEnergies
        , gameOverViewRogueHistory    :: OpenRogueHistory
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

{- |Network: Nodes and Map Energy to Overlay.

The overlays contain the actual Edges

The network itself has no information about its representation.
Representation is handled via NetworkDisplayInfo

-}
data Network =
    Network
        { nodes    :: [Node]
        , overlays :: Map Energy NetworkOverlay
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

-- TODO: include all players
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

data MessageForClient
    = GameView_ GameView
    | GameError_ GameError
    | GameOverView_ GameOverView
    | InitialInfoForClient_ InitialInfoForClient
    deriving (Show, Read, Eq, Generic)

instance FromJSONKey Player where

instance FromJSONKey Node where

instance FromJSONKey Energy where

instance ToJSONKey Player where

instance ToJSONKey Energy where

instance Arbitrary Player  where
    arbitrary =
        Player <$> arbitrary

instance Arbitrary Node  where
    arbitrary =
        Node <$> arbitrary

instance Arbitrary Edge  where
    arbitrary =
        Edge <$> ((,) <$> arbitrary <*> arbitrary)

instance Arbitrary Energy  where
    arbitrary = arbitraryBoundedEnum

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

instance Arbitrary OpenRogueHistory where
    arbitrary =
        OpenRogueHistory <$> arbitrary

instance Arbitrary GameError where
    arbitrary = undefined -- TODO: implement arbitrary for game-error??

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
deriveBoth Elm.Derive.defaultOptions ''Energy
deriveBoth Elm.Derive.defaultOptions ''RogueHistory
deriveBoth Elm.Derive.defaultOptions ''OpenRogueHistory
deriveBoth Elm.Derive.defaultOptions ''GameOverView
deriveBoth Elm.Derive.defaultOptions ''InitialInfoForClient
deriveBoth Elm.Derive.defaultOptions ''MessageForServer
deriveBoth Elm.Derive.defaultOptions ''MessageForClient

-- IsMap implementation for PlayerPositions
Derive.deriveMap ''PlayerPositions
-- IsMap implementation for EnergyMap
Derive.deriveMap ''EnergyMap
-- IsMap implementation for PlayerEnergies
Derive.deriveMap ''PlayerEnergies

-- MonoFoldable and MonoTraversable and IsSequence for RogueHistory
type instance Element RogueHistory = (Energy, Maybe Node)
instance Monoid RogueHistory where
    mempty = RogueHistory mempty
    mappend m1 m2 = RogueHistory $ rogueHistory m1 ++ rogueHistory m2
instance MonoFunctor RogueHistory where
    omap f = RogueHistory . omap f . rogueHistory
instance MonoFoldable RogueHistory where
    ofoldMap f = ofoldMap f . rogueHistory
    ofoldr f x = ofoldr f x . rogueHistory
    ofoldl' f x = ofoldl' f x . rogueHistory
    otoList = rogueHistory
    olength = olength . rogueHistory
    olength64 = olength64 . rogueHistory
    ofoldr1Ex f = ofoldr1Ex f . rogueHistory
    ofoldl1Ex' f = ofoldl1Ex' f . rogueHistory
instance MonoTraversable RogueHistory where
    otraverse f = map RogueHistory . otraverse f . rogueHistory
instance GrowingAppend RogueHistory where
instance Semigroup RogueHistory where
instance SemiSequence RogueHistory where
    type Index RogueHistory = Int
    intersperse e = RogueHistory . intersperse e . rogueHistory
    reverse = RogueHistory . reverse . rogueHistory
    find p = find p . rogueHistory
    sortBy f = RogueHistory . sortBy f . rogueHistory
    cons e = RogueHistory . cons e . rogueHistory
    snoc s e = RogueHistory . flip snoc e . rogueHistory $ s
instance MonoPointed RogueHistory where
    opoint = RogueHistory . singleton
instance IsSequence RogueHistory where
    fromList = RogueHistory . fromList
    -- maybe others for performance..

-- MonoFoldable and MonoTraversable and IsSequence for OpenRogueHistory
type instance Element OpenRogueHistory = (Energy, Node, Bool)
instance Monoid OpenRogueHistory where
    mempty = OpenRogueHistory mempty
    mappend m1 m2 = OpenRogueHistory $ openRogueHistory m1 ++ openRogueHistory m2
instance MonoFunctor OpenRogueHistory where
    omap f = OpenRogueHistory . omap f . openRogueHistory
instance MonoFoldable OpenRogueHistory where
    ofoldMap f = ofoldMap f . openRogueHistory
    ofoldr f x = ofoldr f x . openRogueHistory
    ofoldl' f x = ofoldl' f x . openRogueHistory
    otoList = openRogueHistory
    olength = olength . openRogueHistory
    olength64 = olength64 . openRogueHistory
    ofoldr1Ex f = ofoldr1Ex f . openRogueHistory
    ofoldl1Ex' f = ofoldl1Ex' f . openRogueHistory
instance MonoTraversable OpenRogueHistory where
    otraverse f = map OpenRogueHistory . otraverse f . openRogueHistory
instance GrowingAppend OpenRogueHistory where
instance Semigroup OpenRogueHistory where
instance SemiSequence OpenRogueHistory where
    type Index OpenRogueHistory = Int
    intersperse e = OpenRogueHistory . intersperse e . openRogueHistory
    reverse = OpenRogueHistory . reverse . openRogueHistory
    find p = find p . openRogueHistory
    sortBy f = OpenRogueHistory . sortBy f . openRogueHistory
    cons e = OpenRogueHistory . cons e . openRogueHistory
    snoc s e = OpenRogueHistory . flip snoc e . openRogueHistory $ s
instance MonoPointed OpenRogueHistory where
    opoint = OpenRogueHistory . singleton
instance IsSequence OpenRogueHistory where
    fromList = OpenRogueHistory . fromList
    -- maybe others for performance..
