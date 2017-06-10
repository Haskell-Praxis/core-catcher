module Main exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import WebSocket
import View.MapView exposing (mapView)
import View.TransportView exposing (transportView)
import Debug exposing (log)
import Example.ExampleNetwork as Example
import Example.ExampleGameView as Example
import Example.ExampleGameViewDisplay as Example
import Protocol exposing (..)
import ProtocolUtils exposing (..)
import GameViewDisplay exposing (..)
import ClientState exposing (..)
import Json.Encode exposing (encode)
import Json.Decode exposing (decodeString)
import AllDict exposing (..)


main : Program Never ClientState Msg
main =
    log2 "start state"
        initialState
        -- TODO: remove
        program
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


init : ( ClientState, Cmd Msg )
init =
    ( initialState, Cmd.none )


view : ClientState -> Html Msg
view state =
    div []
        [ h1 [] [ text "Core catcher" ]
        , mapView network displayInfo state
        , transportView network displayInfo state
        ]


wsUrl : String
wsUrl =
    "ws://localhost:3000"


subscriptions : ClientState -> Sub Msg
subscriptions _ =
    WebSocket.listen wsUrl Received


update : Msg -> ClientState -> ( ClientState, Cmd Msg )
update msg state =
    case log "msg" msg of
        Clicked n ->
            state ! [ WebSocket.send wsUrl << log "send" <| jsonActionOfNode state n ]

        Received s ->
            case decodeString jsonDecRogueGameView s of
                Ok newView ->
                    {state | gameView = RogueView newView } ! []

                -- TODO: not only RogueView constructor
                Err err ->
                    log2 "error" err state ! []
        
        SelectEnergy transport ->
            { state | selectedEnergy = transport } ! []



-- random dev helper functions and type defs


initialState : ClientState
initialState =
    { gameView = RogueView Example.rogueGameView
    , selectedEnergy = { transportName = "taxi" }
    }


network : Network
network =
    Example.network


displayInfo : GameViewDisplayInfo
displayInfo =
    Example.displayInfo


jsonActionOfNode : ClientState -> Node -> String
jsonActionOfNode state n =
    encode 0
        << jsonEncAction
    <|
        { player = { playerId = 1 }
        , transport = state.selectedEnergy
        , node = n
        }


cons : a -> b -> a
cons a b =
    a


log2 : String -> a -> b -> b
log2 s a b =
    cons b (log s a)
