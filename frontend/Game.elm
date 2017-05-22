module Game exposing (..)

{-
   - one possibility for Network type
-}

import Dict exposing (..)
import Maybe exposing (..)


{-| The type of node: Id by Int
-}
type alias Node =
    Int


{-| The type of edge is a connection between nodes.
-}
type alias Edge =
    ( Node, Node )


{-| The type of transportation is a string
-}
type alias Transportation =
    String



-- TODO: adapt comments


{-| Network: Nodes and Map Transportation to Overlay.

The overlays contain the actual Edges

The network itself has no information about its representation.
Representation is handled via NetworkDisplayInfo

-}
type alias Network =
    { nodes : List Node
    , overlays : Dict Transportation NetworkOverlay
    }


{-| NetworkOverlay: Sub-Graph that contains several nodes

First part: the contained nodes in the Overlay.
The nodes have to be contained in the nodes of the enclosing network
Second part: the edges of the
The edges must only connect the nodes contained in the first list.

-}
type alias NetworkOverlay =
    { nodes : List Node
    , edges : List Edge
    }


{-| Type that describes a player (an Id for now)
-}
type alias Player =
    Int


{-| Type that models the game state.

Each player stands on a specific node.

-}
type alias GameState =
    Dict Player Node


{-| Types of colors possible for overlays. For now: a string
-}
type alias Color =
    String


{-| Type to describe the width of svg lines (the edges)
-}
type alias EdgeWidth =
    Int


{-| Type to describe the size of the nodes within the svg
-}
type alias NodeSize =
    Int


{-| A map that contains the mappings from transportation type to color.

Each transportation type should be present in this map.

-}
type alias ColorMap =
    Dict Transportation Color


{-| A map that contains the edge widths for each Transportation type.

Each transportation type should be present in this map.

-}
type alias EdgeWidthMap =
    Dict Transportation EdgeWidth


{-| A map that contains the node sizes for each Transportation type.
This is the size of the circle that lies behind a node to represent
that the node has a stop for the given transport

Each transportation type should be present in this map.

-}
type alias NodeSizeMap =
    Dict Transportation NodeSize


{-| A map that mapps nodes to coordinates
-}
type alias NodeXyMap =
    Dict Node ( Int, Int )


type alias PlayerColorMap =
    Dict Player Color


{-| A tuple that contains all information needed to display a network.

The first 3 entries are maps that store the color, edgeWidth and nodeSize per transport type

The 4th entry is a map of coordinates per node

The 5th entry is the list of transportations used in order which they should be rendered.
The smallest / thinnest transport type should be namen last.

The 6th entry is a map that mapps each player to a color

-}
type alias NetworkDisplayInfo =
    { colorMap : ColorMap
    , edgeWidthMap : EdgeWidthMap
    , nodeSizeMap : NodeSizeMap
    , nodeXyMap : NodeXyMap
    , transportPriorityList : List Transportation
    , playerColorMap : PlayerColorMap
    }



--( ColorMap, EdgeWidthMap, NodeSizeMap, NodeXyMap, List Transportation, PlayerColorMap )


{-| A tuple that contains all information needed to display a single networkOverlay.

The 1st entry is the color in which the edges and node rings are drawn.
The 2nd entry is the width of the edges, the 3rd is the size of the rings around the nodes.

The 4th entry is a map of coordinates per node, the same in the NetworkDisplayInfo type.

-}
type alias OverlayDisplayInfo =
    { color : Color
    , edgeWidth : EdgeWidth
    , nodeSize : NodeSize
    , nodeXyMap : NodeXyMap
    }


type alias Game =
    { network : Network
    , displayInfo : NetworkDisplayInfo
    , gameState : GameState
    }


{-| extract the OverlayDisplayInfo from the NetworkDisplayInfo for one transportation type.

Returns `Nothing` if the given transportation type is missing in at least one of the
NetworkDisplayInfo maps is missing.

-}
displayInfoForTransportation : NetworkDisplayInfo -> Transportation -> Maybe OverlayDisplayInfo
displayInfoForTransportation { colorMap, edgeWidthMap, nodeSizeMap, nodeXyMap } transport =
    Maybe.map4
        (\c e n xy ->
            { color = c
            , edgeWidth = e
            , nodeSize = n
            , nodeXyMap = xy
            }
        )
        (get transport colorMap)
        (get transport edgeWidthMap)
        (get transport nodeSizeMap)
        (Just nodeXyMap)


{-| get the X coordinates of the node within the svg, given the map of coordinates
-}
nodeX : NodeXyMap -> Node -> Int
nodeX nodeXyMap n =
    50
        + 100
        * (Maybe.withDefault 0
            << Maybe.map Tuple.first
            << get n
           <|
            nodeXyMap
          )


{-| get the Y coordinates of the node within the svg, given the map of coordinates
-}
nodeY : NodeXyMap -> Node -> Int
nodeY nodeXyMap n =
    50
        + 100
        * (Maybe.withDefault 0
            << Maybe.map Tuple.second
            << get n
           <|
            nodeXyMap
          )


{-| helper function to extract the index of an element in the list (not in core)
-}
indexOf : a -> List a -> Maybe Int
indexOf a l =
    case l of
        [] ->
            Nothing

        x :: xs ->
            if a == x then
                Just 0
            else
                Maybe.map ((+) 1) <| indexOf a xs


{-| gets the priority value for the given transportation.

The overlays with higher priority are drawn first

This is the reverse order of the list in NetworkDisplayInfo

-}
getPriority : NetworkDisplayInfo -> Transportation -> Int
getPriority { transportPriorityList } t =
    Maybe.withDefault -1 << indexOf t <| transportPriorityList


movePlayerInGame : Game -> Player -> Node -> Game
movePlayerInGame game player newNode =
    { game | gameState = Dict.update player (\_ -> Just newNode) game.gameState }
