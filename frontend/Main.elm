module Main exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import WebSocket
import View.MapView exposing (mapView)
import View.TransportView exposing (transportView)
import Debug exposing (log)
import Example.ExampleGameViewDisplay as Example
import Protocol exposing (..)
import ProtocolUtils exposing (..)
import GameViewDisplay exposing (..)
import ClientState exposing (..)
import Json.Encode exposing (encode)
import Json.Decode exposing (decodeString)
import AllDict exposing (..)


main : Program Flags ClientState Msg
main =
    programWithFlags
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


init : Flags -> ( ClientState, Cmd Msg )
init flags =
    initialState flags ! []


view : ClientState -> Html Msg
view state =
    div []
        [ h1 [] [ text <| "Core catcher (Player " ++ toString state.player.playerId ++ ")" ]
        , mapView state.network displayInfo state
        , transportView state.network displayInfo state
        ]


wsUrl : String -> String
wsUrl server =
    "ws://" ++ server ++ ":8000"


subscriptions : ClientState -> Sub Msg
subscriptions state =
    WebSocket.listen (wsUrl state.server) receivedStringToMsg



--|


receivedStringToMsg : String -> Msg
receivedStringToMsg s =
    case decodeString jsonDecMessageForClient s of
        Ok msg ->
            MsgFromServer msg

        Err err ->
            None



-- TODO: handle json error?


update : Msg -> ClientState -> ( ClientState, Cmd Msg )
update msg state =
    case log "msg" msg of
        Clicked n ->
            state ! [ WebSocket.send (wsUrl state.server) << log "send" <| jsonActionOfNode state n ]

        MsgFromServer msg ->
            case msg of
                GameView_ gameView ->
                    { state | gameView = gameView } ! []

                InitialInfoForClient_ initInfo ->
                    { state
                        | gameView = initInfo.initialGameView
                        , player = initInfo.initialPlayer
                        , network = initInfo.networkForGame
                    }
                        ! []

        SelectEnergy transport ->
            { state | selectedEnergy = transport } ! []

        None ->
            state ! []



-- random dev helper functions


initialState : Flags -> ClientState
initialState flags =
    { gameView = RogueView emptyRogueView
    , network = emptyNetwork
    , player = { playerId = 0 }
    , selectedEnergy = { transportName = "orange" }
    , server = flags.server
    }

displayInfo : GameViewDisplayInfo
displayInfo =
    Example.displayInfo


jsonActionOfNode : ClientState -> Node -> String
jsonActionOfNode state n =
    encode 0
        << jsonEncAction
    <|
        { actionPlayer = state.player
        , actionTransport = state.selectedEnergy
        , actionNode = n
        }


cons : a -> b -> a
cons a b =
    a


log2 : String -> a -> b -> b
log2 s a b =
    cons b (log s a)
