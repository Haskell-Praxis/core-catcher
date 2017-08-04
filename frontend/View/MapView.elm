module View.MapView exposing (mapView)

import Html as Html
import Html.Attributes as Html
import Html.Events exposing (onClick)
import Svg exposing (..)
import Svg.Attributes exposing (..)
import List exposing (..)
import Dict exposing (..)
import AllDict exposing (..)
import ClientState exposing (..)
import Protocol exposing (..)
import ProtocolUtils exposing (..)
import GameViewDisplay exposing (..)

-- TODO: css style with css-library?

mapView : Network -> GameViewDisplayInfo -> ClientState -> Html.Html Msg
mapView network displayInfo clientState =
    svg
        [ height << toString <| displayInfo.mapHeight
        , width << toString <| displayInfo.mapWidth
        , Html.style [ ( "backgroundColor", "#cccccc" ) ]
        ]
    -- elements of svg now
    <|
        []
            ++ List.concatMap
                -- overlays
                (mapViewOfNetworkOverlayName displayInfo network)
                (List.sortBy (\( transport, _ ) -> getPriority displayInfo transport) network.overlays)
            -- base network
            ++ List.map (nodeCircle displayInfo.nodeXyMap) network.nodes
            ++ List.map (playerCircle displayInfo.nodeXyMap displayInfo.playerColorMap)
                (playerPositions clientState.gameView).playerPositions


mapViewOfNetworkOverlayName : GameViewDisplayInfo -> Network -> ( Transport, NetworkOverlay ) -> List (Svg.Svg Msg)
mapViewOfNetworkOverlayName displayInfo { overlays } ( overlayName, overlay ) =
    (Maybe.withDefault []
        << Maybe.map2 (mapViewOfNetworkOverlay)
            (displayInfoForTransport displayInfo overlayName)
     <|
        Just overlay
    )


mapViewOfNetworkOverlay : OverlayDisplayInfo -> NetworkOverlay -> List (Svg Msg)
mapViewOfNetworkOverlay { color, edgeWidth, nodeSize, nodeXyMap } { overlayNodes, overlayEdges } =
    List.map (edgeLine nodeXyMap color edgeWidth) overlayEdges
        ++ List.map (nodeCircleStop nodeXyMap color nodeSize) overlayNodes



-- svg create functions


nodeCircleStop : NodeXyMap -> Color -> NodeSize -> Node -> Svg Msg
nodeCircleStop nodeXyMap color size node =
    circle
        [ cx << toString <| nodeX nodeXyMap node
        , cy << toString <| nodeY nodeXyMap node
        , r (toString size)
        , fill color
        , onClick (Clicked node)
        , Html.style [ ( "cursor", "pointer" ) ]
        ]
        []


nodeCircle : NodeXyMap -> Node -> Svg Msg
nodeCircle nodeXyMap node =
    Svg.g []
        [ circle
            [ cx << toString << nodeX nodeXyMap <| node
            , cy << toString << nodeY nodeXyMap <| node
            , r "20"
            , fill "#111111"
            , Svg.Attributes.cursor "pointer"
            , onClick (Clicked node)
            ]
            []
        , text_
            [ x << toString <| nodeX nodeXyMap node
            , y << toString <| 5 + nodeY nodeXyMap node
            , fill "#ffffff"
            , Svg.Attributes.cursor "pointer"
            , onClick (Clicked node)
            , textAnchor "middle"
            ]
            [ text << toString <| node.nodeId ]
        ]


playerCircle : NodeXyMap -> PlayerColorMap -> ( Player, Node ) -> Svg Msg
playerCircle nodeXyMap playerColorMap ( player, node ) =
    circle
        [ cx << toString << nodeX nodeXyMap <| node
        , cy << toString << nodeY nodeXyMap <| node
        , r "15"
        , fill "none"
        , stroke << Maybe.withDefault "white" << AllDict.get player <| playerColorMap
        , Svg.Attributes.cursor "pointer"
        , onClick (Clicked node)
        , strokeWidth "4"
        , Svg.Attributes.strokeDasharray "5,3.5"
        ]
        []


edgeLine : NodeXyMap -> Color -> EdgeWidth -> Edge -> Svg msg
edgeLine nodeXyMap color edgeWidth { edge } =
    let
        ( n1, n2 ) =
            edge
    in
        line
            [ x1 << toString << nodeX nodeXyMap <| n1
            , y1 << toString << nodeY nodeXyMap <| n1
            , x2 << toString << nodeX nodeXyMap <| n2
            , y2 << toString << nodeY nodeXyMap <| n2
            , strokeWidth (toString edgeWidth)
            , stroke color
            ]
            []
