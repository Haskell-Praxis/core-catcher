module Main exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import WebSocket
import View.MapView exposing (mapView)
import View.GameViewDisplay exposing (..)
import View.EnergyView exposing (..)
import Debug exposing (log)
import Example.ExampleGameViewDisplay as Example
import Protocol exposing (..)
import ProtocolUtils exposing (..)
import ClientState exposing (..)
import Json.Encode exposing (encode)
import Json.Decode exposing (decodeString)
import EveryDict
import AllDict exposing (AllDict)
import Navigation exposing (..)
import AnimationFrame exposing (diffs)

main : Program Never ClientState Msg
main =
    Navigation.program (const None)
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


init : Location -> ( ClientState, Cmd Msg )
init location =
    initialState location ! []



-- enable this instead of "! []" for automiatic login
--        ! [ send location.hostname <|
--                Login_
--                    { loginPlayer =
--                        { playerName = "Alice" }
--                    }
--          ]


view : ClientState -> Html Msg
view state =
    case state of
        PreGame_ preGame ->
            preGameView preGame

        GameState_ gameState ->
            gameView gameState


preGameView : PreGame -> Html Msg
preGameView state =
    div []
        [ h1 [] [ text <| "Core catcher" ]
        , Html.form [ onSubmit (DoLogin { loginPlayer = { playerName = state.playerNameField } }) ]
            [ input [ placeholder "Username", onInput PlayerNameChange, autofocus True ] []
            , button [ type_ "submit" ] [ text "Login" ]
            ]
        ]


gameView : GameState -> Html Msg
gameView state =
    div []
        [ mapView state.network state.displayInfo state
        , energyOverview state.network state.displayInfo state
        ]


wsUrl : String -> String
wsUrl server =
    "ws://" ++ server ++ ":7999"


subscriptions : ClientState -> Sub Msg
subscriptions state =
    Sub.batch
        [ WebSocket.listen (wsUrl <| getServer state) receivedStringToMsg
        , case state of
            PreGame_ _ ->
                Sub.none

            GameState_ state ->
                if (AllDict.toList state.activeAnimations == []) then
                    Sub.none
                else
                    diffs Tick
        ]


receivedStringToMsg : String -> Msg
receivedStringToMsg s =
    case decodeString jsonDecMessageForClient s of
        Ok msg ->
            MsgFromServer msg

        Err err ->
            -- TODO: popup for that?
            -- how to handle json error?
            log2 "error" err None


update : Msg -> ClientState -> ( ClientState, Cmd Msg )
update msg state =
    case ( log "msg" msg, state ) of
        ( Movement n, GameState_ state ) ->
            GameState_ { state | gameError = Nothing }
                ! [ send state.server <| msgForActionOfNode state n
                  ]

        ( MsgFromServer (GameView_ gameView), GameState_ state ) ->
            GameState_
                { state
                    | playerPositions = playerPositions gameView
                    , playerEnergies = playerEnergies gameView
                    , rogueHistory = rogueHistory gameView
                    , nextPlayer = Just <| nextPlayer gameView
                    , activeAnimations = updateActiveAnimations state gameView
                }
                ! []

        ( MsgFromServer (GameError_ err), GameState_ state ) ->
            GameState_ { state | gameError = Just err } ! []

        ( MsgFromServer (GameOverView_ gameOver), GameState_ state ) ->
            GameState_
                { state
                    | gameOver = True
                    , playerPositions = gameOver.gameOverViewPlayerPositions
                    , playerEnergies = gameOver.gameOverViewPlayerEnergies
                    , nextPlayer = Nothing

                    --, rogueHistory = gameOver.gameOverViewRogueHistory
                    -- TODO: openRougeHistory
                }
                ! []

        ( MsgFromServer ServerHello, GameState_ state ) ->
            -- reconnect upon ServerHello
            -- TODO: implement, also for other state-objects
            GameState_ state
                ! [ send state.server <|
                        Login_
                            { loginPlayer =
                                { playerName = state.player.playerName }
                            }
                  ]

-- TODO: implement that if already in game (i.e. reconnect)
        ( MsgFromServer (InitialInfoForClient_ initInfo), PreGame_ preGame ) ->
            GameState_
                { network = initInfo.networkForGame
                , players = initInfo.allPlayers
                , energies = initInfo.allEnergies
                , playerPositions = playerPositions initInfo.initialGameView
                , playerEnergies = playerEnergies <| initInfo.initialGameView
                , rogueHistory = rogueHistory <| initInfo.initialGameView
                , nextPlayer = Just <| nextPlayer initInfo.initialGameView
                , selectedEnergy = Orange
                , gameError = Nothing
                , gameOver = False
                , server = preGame.server
                , player = initInfo.initialPlayer
                , animationTime = 0
                , activeAnimations = AllDict.empty .playerName
                , displayInfo = Example.displayInfo
                }
                ! []

        -- other message that is not recognized
        ( MsgFromServer _, GameState_ state ) ->
            -- TODO: error for that
            GameState_ state ! []

        ( Tick dt, GameState_ state ) ->
            GameState_
                { state
                    | animationTime = dt + state.animationTime
                    , activeAnimations =
                        -- filter done animations
                        log "filtered" <| AllDict.filter
                            (\_ a ->
                                a.startTime
                                    + state.displayInfo.movementAnimationDuration
                                    > state.animationTime
                            )
                            state.activeAnimations
                }
                ! []

        ( SelectEnergy energy, GameState_ state ) ->
            GameState_ { state | selectedEnergy = energy } ! []

        ( None, state ) ->
            state ! []

        ( PlayerNameChange newPlayerName, PreGame_ state ) ->
            PreGame_ { state | playerNameField = newPlayerName } ! []

        ( DoLogin login, PreGame_ state ) ->
            PreGame_ state
                ! [ send state.server <|
                        Login_
                            { loginPlayer =
                                { playerName = state.playerNameField }
                            }
                  ]

        ( _, state ) ->
            -- TODO: error for that
            state ! []


initialState : Location -> ClientState
initialState location =
    PreGame_
        { server = location.hostname
        , playerNameField = ""
        }


send : String -> MessageForServer -> Cmd a
send server msg =
    WebSocket.send (wsUrl server)
        << encode 0
        << jsonEncMessageForServer
    <|
        log "ws-send" msg


msgForActionOfNode : GameState -> Node -> MessageForServer
msgForActionOfNode state n =
    Action_
        { actionPlayer = state.player
        , actionEnergy = state.selectedEnergy
        , actionNode = n
        }


updateActiveAnimations : GameState -> GameView -> AllDict Player PlayerMovementAnimation String
updateActiveAnimations gameState gameView =
    let
        movingPlayer =
            gameState.nextPlayer

        newAnimation =
            Maybe.map2
                (\fromNode toNode ->
                    { fromNode = fromNode
                    , toNode = toNode
                    , startTime = gameState.animationTime
                    }
                )
                -- fromNode
                (Maybe.andThen
                    (\p ->
                        EveryDict.get p
                            gameState.playerPositions.playerPositions
                    )
                    movingPlayer
                )
                -- toNode
                (Maybe.andThen
                    (\p ->
                        EveryDict.get p
                            << .playerPositions
                            << playerPositions
                        <|
                            gameView
                    )
                    movingPlayer
                )
    in
        log "active animations" <| case ( newAnimation, movingPlayer ) of
            ( Just a, Just p ) ->
                AllDict.insert p a gameState.activeAnimations

            _ ->
                gameState.activeAnimations


const : a -> b -> a
const a b =
    a


log2 : String -> a -> b -> b
log2 s a b =
    const b (log s a)
