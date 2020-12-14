module Main exposing (main)

import Ant.Css
import Api exposing (Api)
import Browser
import Css.ModernNormalize as NormalizeCss
import Html exposing (div, Html)
import Html.Attributes as Attr
import ParlezVousEmbed
import Task
import Time
import Url


type alias Flags = 
    { apiEndpoint : String
    , siteUrl : String
    }


main : Program Flags Model Msg 
main =
  Browser.element
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


-- MODEL

type Model
    = Ready ParlezVousEmbed.Model
    | NotReady Api
    | Failed String


-- MSG

type Msg
    = AppMsg ParlezVousEmbed.Msg
    | NewCurrentTime Time.Posix


-- INIT

init : Flags -> (Model, Cmd Msg)
init flags =
    case ( Url.fromString flags.apiEndpoint, Url.fromString flags.siteUrl ) of
        ( Just apiBaseUrl, Just siteUrl ) ->
            let
                api = Api.apiFactory apiBaseUrl siteUrl
            in
            ( NotReady api, Task.perform NewCurrentTime Time.now)

        _ ->
            ( Failed <| "invalid api endpoint or site url: " ++ "(" ++ flags.apiEndpoint ++ ", " ++ flags.siteUrl ++ ")"
            , Cmd.none
            )



-- UPDATE

updateReadyModel : Msg -> ParlezVousEmbed.Model -> ( Model, Cmd Msg )
updateReadyModel msg embedModel =
    case msg of
        AppMsg appMsg -> 
            let
                ( newEmbedModel, embedCmd ) = ParlezVousEmbed.update appMsg embedModel
            in
            ( Ready newEmbedModel 
            , Cmd.map AppMsg embedCmd
            )

        NewCurrentTime time ->
            ( Ready <| ParlezVousEmbed.setCurrentTime time embedModel
            , Cmd.none 
            )
            

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( model, msg ) of
        ( Failed reason, _ ) ->
            ( Failed reason, Cmd.none )

        ( NotReady api, NewCurrentTime time ) ->
            let
                ( embedModel, embedCmd ) = ParlezVousEmbed.init api time
            in
            ( Ready embedModel, Cmd.map AppMsg embedCmd )

        ( NotReady api, _ ) ->
            ( NotReady api, Cmd.none )


        ( Ready embedModel, _ ) ->
            updateReadyModel msg embedModel




-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions _ =
    let
        fiveMinutes = 1000 * 60 * 5
    in
    Time.every fiveMinutes NewCurrentTime 


-- VIEW

view : Model -> Html Msg
view model =
    let
        contents =
            case model of
                Failed reason ->
                    Html.text reason

                NotReady _ ->
                    div [] []

                Ready embedModel ->
                    ParlezVousEmbed.viewApp embedModel
                    |> Html.map AppMsg

    in
    div [ Attr.class "parlez-container" ]
        [ NormalizeCss.globalHtml
        , Ant.Css.defaultStyles
        , contents
        ]

