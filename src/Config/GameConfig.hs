{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Config.GameConfig (GameConfig(..), defaultConfig) where

import           ClassyPrelude
import           Network.Protocol

data GameConfig =
    GameConfig
        { players                :: [Player]
        , initialPlayerEnergies  :: PlayerEnergies
        , initialPlayerPositions :: PlayerPositions
        , maxRounds              :: Int
        , rogueShowsAt           :: [Int]
        }

-- TODO: configurable network

-- | The default GameConfig
defaultConfig :: GameConfig
defaultConfig = GameConfig
    { players = defaultPlayers
    , initialPlayerEnergies = defaultInitialPlayerEnergies
    , initialPlayerPositions = defaultInitialPlayerPositions
    , maxRounds = 10
    , rogueShowsAt = [2,5,8,10]
    }

defaultPlayers :: [Player]
defaultPlayers = fromList . map Player $ [0..3]

defaultInitialPlayerPositions :: PlayerPositions
defaultInitialPlayerPositions =
    mapFromList . zip defaultPlayers . map Node $ [1, 4, 2, 14]


defaultInitialPlayerEnergies :: PlayerEnergies
defaultInitialPlayerEnergies =
    mapFromList . zip defaultPlayers . repeat $ initialEnergiesPerPlayer

initialEnergiesPerPlayer :: EnergyMap
initialEnergiesPerPlayer =
    mapFromList
        [ ( Transport "orange", 5 )
        , ( Transport "blue", 3 )
        , ( Transport "red", 2 )
        ]
