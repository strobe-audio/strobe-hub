module Settings exposing (..)


type alias Model =
    { application : String
    , saving : Bool
    , namespaces : List NameSpace
    }


type alias NameSpace =
    { application : String
    , namespace : String
    , title : String
    , fields : Fields
    }


type alias Fields =
    List Field


type alias Field =
    { application : String
    , namespace : String
    , name : String
    , value: String
    , inputType : String
    }


updateField : Field -> String -> Model -> Model
updateField field value model =
    let
        namespaces =
            List.map
                (\ns ->
                    if ns.namespace == field.namespace then
                        updateNamespace field value ns
                    else
                        ns
                )
                model.namespaces
    in
        { model | namespaces = namespaces }


updateNamespace : Field -> String -> NameSpace -> NameSpace
updateNamespace field value ns =
    let
        fields =
            List.map
                (\f ->
                    if f == field then
                        { f | value = value }
                    else
                        f
                )
                ns.fields
    in
        { ns | fields = fields }
