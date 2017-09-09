{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Config.GameConfig
  ( GameConfig(..)
  , defaultConfig
  , defaultConfigWithRandomPositions
  , getRogue
  ) where

import           ClassyPrelude
import qualified Config.Network   as Network
import           Data.List        (nub)
import           Network.Protocol
import qualified System.Random    as Random

data GameConfig =
    GameConfig
        { players                :: NonNull (Seq Player)
        , initialPlayerEnergies  :: PlayerEnergies
        , initialPlayerPositions :: PlayerPositions
        , maxRounds              :: Int
        , rogueShowsAt           :: [Int]
        , network                :: Network
        }
    deriving (Eq, Show, Read)

getRogue :: GameConfig -> Player
getRogue = head . players


defaultConfigWithRandomPositions :: IO GameConfig
defaultConfigWithRandomPositions = do
    playerPos <- randomPositions (length $ nodes Network.network)
    return GameConfig
        { players = impureNonNull $ fromList defaultPlayers
        , initialPlayerEnergies = defaultInitialPlayerEnergies
        , initialPlayerPositions = playerPos
        , maxRounds = 10
        , rogueShowsAt = [1,4,7,10]
        , network = Network.network
        }


randomPositions :: Int -> IO PlayerPositions
randomPositions nodeNum = do
    gen <- Random.newStdGen
    let rands = nub $ Random.randomRs (1, nodeNum) gen
    return . mapFromList . zip defaultPlayers . map Node $ rands



-- | The default GameConfig
defaultConfig :: GameConfig
defaultConfig = GameConfig
    { players = impureNonNull $ fromList defaultPlayers
    , initialPlayerEnergies = defaultInitialPlayerEnergies
    , initialPlayerPositions = defaultInitialPlayerPositions
    , maxRounds = 10
    , rogueShowsAt = [1,4,7,10]
    , network = Network.network
    }

defaultPlayers :: [Player]
defaultPlayers = map Player ["Alice", "Bob", "Charlie"]

defaultInitialPlayerPositions :: PlayerPositions
defaultInitialPlayerPositions =
    mapFromList . zip defaultPlayers . map Node $ [1, 4, 12]


defaultInitialPlayerEnergies :: PlayerEnergies
defaultInitialPlayerEnergies =
    mapFromList . zip defaultPlayers . repeat $ initialEnergiesPerPlayer

initialEnergiesPerPlayer :: EnergyMap
initialEnergiesPerPlayer =
    mapFromList
        [ ( Orange, 7 )
        , ( Blue, 4 )
        , ( Red, 2 )
        ]
