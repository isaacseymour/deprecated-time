module Time.Iso8601 exposing
    ( fromDate, fromDateTime, fromZonedDateTime
    , toDate, toDateTime, toZonedDateTime
    , Problem(..)
    )

{-|


# Render ISO8601 strings

@docs fromDate, fromDateTime, fromZonedDateTime


# Parse ISO8601 strings

@docs toDate, toDateTime, toZonedDateTime


# Possible errors

@docs Problem

-}

import Char
import Parser.Advanced
    exposing
        ( (|.)
        , (|=)
        , DeadEnd
        , Parser
        , Token(..)
        , andThen
        , chompIf
        , chompWhile
        , getChompedString
        , inContext
        , oneOf
        , problem
        , run
        , succeed
        , symbol
        )
import Time.Date as Date
    exposing
        ( Date
        , daysInMonth
        , isValidDate
        )
import Time.DateTime as DateTime
    exposing
        ( DateTime
        , addMilliseconds
        , dateTime
        , day
        , hour
        , makeDateTime
        , millisecond
        , minute
        , month
        , second
        , year
        )
import Time.Internal
    exposing
        ( hourMs
        , minuteMs
        , offsetFromTimeData
        , padded
        , padded3
        )
import Time.TimeZone exposing (TimeZone)
import Time.ZonedDateTime as ZDT exposing (ZonedDateTime)


type alias Context =
    String


{-| Issues parsing an ISO8601 date
-}
type Problem
    = ExpectingDigit
    | ExpectingRange Int Int Int
    | ExpectingDot
    | ExpectingZ
    | ExpectingSign
    | BadInt
    | InvalidDate ( Int, Int, Int )
    | ExpectingNDigits Int String
    | Other String


type alias IsoParser value =
    Parser Context Problem value


type alias IsoDeadEnd =
    DeadEnd Context Problem



-- Shared parsers
-- --------------


{-| Offset is expressed in +/- milliseconds
-}
type alias Milliseconds =
    Int


{-| fromDate renders a Date in ISO8601 format.

    import Time.Date exposing (..)

    date 2018 5 27
    |> fromDate
    --> "2018-05-27"

-}
fromDate : Date -> String
fromDate date =
    (String.fromInt (Date.year date) |> String.padLeft 4 '0')
        ++ "-"
        ++ padded (Date.month date)
        ++ "-"
        ++ padded (Date.day date)


{-| fromDateTime renders a DateTime in ISO8601 format.

    import Time.DateTime

    Time.DateTime.epoch
    |> Time.DateTime.addMilliseconds 61000
    |> fromDateTime
    --> "1970-01-01T00:01:01.000Z"

-}
fromDateTime : DateTime -> String
fromDateTime time =
    String.fromInt (year time)
        ++ "-"
        ++ padded (month time)
        ++ "-"
        ++ padded (day time)
        ++ "T"
        ++ padded (hour time)
        ++ ":"
        ++ padded (minute time)
        ++ ":"
        ++ padded (second time)
        ++ "."
        ++ padded3 (millisecond time)
        ++ "Z"


{-| fromZonedDateTime renders a ZonedDateTime in ISO8601 format.

    import Time.ZonedDateTime
    import Time.TimeZones exposing (america_new_york)
    import Time.DateTime exposing (epoch)

    Time.ZonedDateTime.fromDateTime america_new_york epoch
    |> fromZonedDateTime
    --> "1969-12-31T19:00:00.000-05:00"

-}
fromZonedDateTime : ZonedDateTime -> String
fromZonedDateTime dateTime =
    String.fromInt (ZDT.year dateTime)
        ++ "-"
        ++ padded (ZDT.month dateTime)
        ++ "-"
        ++ padded (ZDT.day dateTime)
        ++ "T"
        ++ padded (ZDT.hour dateTime)
        ++ ":"
        ++ padded (ZDT.minute dateTime)
        ++ ":"
        ++ padded (ZDT.second dateTime)
        ++ "."
        ++ padded3 (ZDT.millisecond dateTime)
        ++ ZDT.utcOffsetString dateTime


{-| toZonedDateTime parses an ISO8601-formatted string into a
ZonedDateTime object, adjusting for its offset.

    import Time.ZonedDateTime
    import Time.TimeZones exposing (america_new_york)
    import Time.DateTime exposing (epoch)

    toZonedDateTime america_new_york "1970-01-01T00:00:00.000Z"
    --> Ok (Time.ZonedDateTime.fromDateTime america_new_york epoch)

-}
toZonedDateTime : TimeZone -> String -> Result (List IsoDeadEnd) ZonedDateTime
toZonedDateTime timeZone input =
    toDateTime input
        |> Result.map (ZDT.fromDateTime timeZone)


{-| toDate parses an ISO8601-formatted date string into a Date.

    import Time.Date

    toDate "1970-12-01"
    --> Ok (Time.Date.date 1970 12 1)

    toDate "19701201"
    --> Ok (Time.Date.date 1970 12 1)

-}
toDate : String -> Result (List IsoDeadEnd) Date
toDate input =
    run parseDate input


{-| -}
parseDate : IsoParser Date
parseDate =
    (succeed (\a b c -> ( a, b, c ))
        |= parseYear
        |. optional '-'
        |= parseMonth
        |. optional '-'
        |= parseDay
    )
        |> andThen convertDate


parseYear : IsoParser Int
parseYear =
    inContext "year" <|
        ((getChompedString <|
            succeed ()
                |. chompIf Char.isDigit ExpectingDigit
                |. chompIf Char.isDigit ExpectingDigit
                |. chompIf Char.isDigit ExpectingDigit
                |. chompIf Char.isDigit ExpectingDigit
         )
            |> andThen (digits 4)
        )


parseMonth : IsoParser Int
parseMonth =
    digitsInRange "month" 1 12


parseDay : IsoParser Int
parseDay =
    digitsInRange "day-in-month" 1 31


digits : Int -> String -> IsoParser Int
digits digitsCount chomped =
    if String.length chomped == digitsCount then
        String.toInt chomped |> fromMaybe

    else
        -- messge:  "expected " ++ String.fromInt digitsCount ++ " digits, got " ++ chomped
        problem <| ExpectingNDigits digitsCount chomped


convertDate : ( Int, Int, Int ) -> IsoParser Date
convertDate ( year, month, day ) =
    if isValidDate year month day then
        succeed (Date.date year month day)

    else
        inContext "leap-year" <|
            problem (InvalidDate ( year, month, day ))


complainInvalid : ( Int, Int, Int ) -> IsoParser Date
complainInvalid ( year, month, day ) =
    let
        -- TODO: move to the errormsg module
        maxDays =
            daysInMonth year month

        msg =
            "Expecting the value "
                ++ String.fromInt day
                ++ " to be in the range 1 to "
                ++ String.fromInt maxDays
                ++ " for the specified year, "
                ++ String.fromInt year
                ++ ", and month, "
                ++ String.fromInt month
                ++ "."
    in
    problem <| InvalidDate ( year, month, day )


digitsInRange : String -> Int -> Int -> IsoParser Int
digitsInRange name lo hi =
    inContext name <|
        ((getChompedString <|
            succeed ()
                |. chompIf Char.isDigit ExpectingDigit
                |. chompIf Char.isDigit ExpectingDigit
         )
            |> andThen (intRange lo hi << String.toInt)
        )


intRange : Int -> Int -> Maybe Int -> IsoParser Int
intRange lo hi result =
    case result of
        Just n ->
            if n >= lo && n <= hi then
                succeed n

            else
                problem (ExpectingRange n lo hi)

        Nothing ->
            problem BadInt


fromMaybe : Maybe Int -> IsoParser Int
fromMaybe =
    Maybe.map succeed >> Maybe.withDefault (problem BadInt)


fromResult : Result String Int -> IsoParser Int
fromResult result =
    case result of
        Ok i ->
            succeed i

        Err msg ->
            problem <| Other msg


optional : Char -> IsoParser ()
optional char =
    chompWhile (\c -> c == char)


{-| toDateTime parses an ISO8601-formatted date time string into a
DateTime object, adjusting for its timezone offset.
-}
toDateTime : String -> Result (List IsoDeadEnd) DateTime
toDateTime input =
    run parseDateTime input


parseDateTime : IsoParser DateTime
parseDateTime =
    (succeed (\a b c -> ( a, b, c ))
        |= parseDate
        |. optional 'T'
        |= parseOffset
        |= tZOffset
    )
        |> andThen convertDateTime


type alias IntermediateOffset =
    { hours : Int
    , minutes : Int
    , seconds : Int
    , milliseconds : Int
    }


parseOffset : IsoParser Milliseconds
parseOffset =
    (succeed IntermediateOffset
        |= digitsInRange "hours" 0 23
        |. optional ':'
        |= digitsInRange "minutes" 0 59
        |. optional ':'
        |= digitsInRange "seconds" 0 59
        |= fraction
    )
        |> andThen convertTime


convertDateTime : ( Date, Milliseconds, Milliseconds ) -> IsoParser DateTime
convertDateTime ( date, offset, tZOffset_ ) =
    succeed
        (makeDateTime
            date
            offset
            |> addMilliseconds tZOffset_
        )


convertTime : IntermediateOffset -> IsoParser Milliseconds
convertTime intermediate =
    succeed
        (offsetFromTimeData
            { hour = intermediate.hours
            , minute = intermediate.minutes
            , second = intermediate.seconds
            , millisecond = intermediate.milliseconds
            }
        )


fraction : IsoParser Milliseconds
fraction =
    oneOf
        [ optionalFraction
        , succeed 0
        ]


optionalFraction : IsoParser Milliseconds
optionalFraction =
    inContext "fraction" <|
        ((getChompedString <|
            symbol (Token "." ExpectingDot)
                |. chompWhile Char.isDigit
         )
            |> andThen (fromResult << getFraction << String.dropLeft 1)
        )


getFraction : String -> Result String Milliseconds
getFraction fractionString =
    let
        numerator =
            Maybe.withDefault 0 (String.toInt fractionString)

        denominator =
            10 ^ String.length fractionString
    in
    Ok (round (Time.Internal.secondMs * toFloat numerator / toFloat denominator))


tZOffset : IsoParser Milliseconds
tZOffset =
    oneOf
        [ utc
        , optionalTZOffset
        , succeed 0
        ]


utc : IsoParser Milliseconds
utc =
    succeed 0 |. symbol (Token "Z" ExpectingZ)


optionalTZOffset : IsoParser Milliseconds
optionalTZOffset =
    inContext "offset" <|
        ((succeed (\a b c -> ( a, b, c ))
            |= polarity
            |= digitsInRange "timezone hours" 0 23
            |. optional ':'
            |= digitsInRange "timezone minutes" 0 59
         )
            |> andThen (fromResult << getTZOffset)
        )


polarity : IsoParser Int
polarity =
    inContext "timezone polarity" <|
        ((getChompedString <|
            succeed ()
                |. chompIf (\c -> c == '+' || c == '-' || c == '−') ExpectingSign
         )
            |> andThen
                (fromResult
                    << -- Code has to do opposite of sign char
                       (\sign ->
                            if sign == "+" then
                                Ok -1

                            else
                                Ok 1
                       )
                )
        )


getTZOffset : ( Int, Int, Int ) -> Result String Milliseconds
getTZOffset ( polarity_, hrs, min ) =
    Ok
        (polarity_
            * hrs
            * hourMs
            + polarity_
            * min
            * minuteMs
        )
