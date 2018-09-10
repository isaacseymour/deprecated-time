# deprecated-time [![Build Status](https://travis-ci.org/isaacseymour/deprecated-time.svg)](https://travis-ci.org/isaacseymour/deprecated-time)

``` shell
elm install isaacseymour/deprecated-time
```

## DEPRECATED

This is a fork of elm-community/elm-time, upgraded to support Elm `0.19`. However, it's not clear
that this is the best way to model time; this package is intended only to make updating your app to
`0.19` easier. It's recommended to consider using newer libraries instead, for example:

- [justinmimbs/date](https://package.elm-lang.org/packages/justinmimbs/date/latest)
- [rtfeldman/elm-iso8601-date-strings](https://package.elm-lang.org/packages/rtfeldman/elm-iso8601-date-strings/latest)
- [ryannhg/date-format](https://package.elm-lang.org/packages/ryannhg/date-format/latest)


If you're sticking with this library for now, there's only minimal changes from the latest version
of elm-community/elm-time:
* Deprecated functions have been removed
* `toTimestamp` and `fromTimestamp` are renamed to `toPosix` and `fromPosix`, and now deal with
  `Time.Posix`, rather than the old Float-based time type


## Dates

`Date`s may represent any date in the [proleptic Gregorian calendar][cal].

``` elm
import Time.Date as Date exposing (Date, date)
```

### Constructing Dates

Use `date` to construct `Date` values.  If given invalid values for
the month and day, they are both clamped and the nearest valid date is
returned.

``` elm
> date 1992 2 28
Date { year = 1992, month = Feb, day = 28 } : Date

> date 1992 2 31
Date { year = 1992, month = Feb, day = 29 } : Date

> date 1992 2 128
Date { year = 1992, month = Feb, day = 29 } : Date
```

Use `year`, `month`, and `day` to inspect `Date`s.

``` elm
> d = date 1992 5 29
Date { year = 1992, month = May, day = 29 } : Date

> Date.year d
1992 : Int

> Date.month d
5 : Int

> Date.day d
29 : Int
```

### Manipulating Dates

`setYear`, `setMonth` and `setDay` can be used to create new `Dates`
containing updated values for each respective field.  Like `date`,
these functions clamp their parameters and return the nearest valid
date.

`addDays` can be used to add an exact number of days to a `Date`.

`addYears` and `addMonths` add a relative number of years and months
to a date.  If the target date is invalid, these functions continually
subtract one day until a valid date is found.

``` elm
import Time.Date as Date exposing (Date, date, addYears)
import Time.Iso8601

> date 1992 1 31
|   |> addYears 1
|   |> Time.Iso8601.fromDate
"1993-01-31" : String

> date 1992 2 29
|   |> addYears 1
|   |> Time.Iso8601.fromDate
"1993-02-28" : String

> date 1992 1 31
|   |> Date.addMonths 1
|   |> Time.Iso8601.fromDate
"1992-02-28" : String
```

## DateTimes

`DateTimes` represent a `Date` together with the time information starting on midnight for the `Date`.

``` elm
import Time.DateTime as DateTime exposing (DateTime, dateTime, year, month, day, hour, minute, second, millisecond)
```

### Constructing DateTimes

`DateTime`s can be constructed from a record using the `dateTime`
function or from a UTC timestamp in milliseconds using `fromPosix`.
To construct a `DateTime` using `dateTime`, pass it a record
containing fields for `year`, `month`, `day`, `hour`, `minute`,
`second` and `millisecond`:

``` elm
dt : DateTime
dt =
    dateTime { year = 1992, month = 5, day = 29, hour = 0, minute = 0, second = 0, millisecond = 0 }

year dt --> 1992
month dt --> 5
day dt --> 29
hour dt --> 0
minute dt --> 0
second --> 0
millisecond --> 0

dt : DateTime
dt =
    dateTime { year = 1992, month = 2, day = 31, hour = 0, minute = 0, second = 0, millisecond = 0 }

year dt --> 1992
month dt --> 2
day dt --> 29 - Note clamped.
hour dt --> 0
minute dt --> 0
second --> 0
millisecond --> 0

dt : DateTime
dt =
    dateTime { year = 1993, month = 2, day = 31, hour = 0, minute = 0, second = 0, millisecond = 0 }

year dt --> 1993
month dt --> 2
day dt --> 28 - Note clamped.
hour dt --> 0
minute dt --> 0
second --> 0
millisecond --> 0
```

To make constructing `DateTimes` less tedious, the library provides
`Time.DateTime.zero`:

``` elm
> import Time.DateTime as DateTime exposing (DateTime, dateTime, zero)

> dateTime { zero | year = 1992 }
|   |> DateTime.toISO8601
"1992-01-01T00:00:00.000Z" : String

> dateTime { zero | year = 1992, month = 2, day = 28, hour = 5 }
|   |> DateTime.toISO8601
"1992-02-28T05:00:00.000Z" : String
```

Use `fromPosix` to construct a `DateTime` from a UTC timestamp in
milliseconds:

``` elm
> fromPosix (Time.millisToPosix 0)
|   |> DateTime.toISO8601
"1970-01-01T00:00:00.000Z" : String
```

See `examples/without-timezone` for an example of how to construct
`DateTime`s from local time.

### Manipulating DateTimes

Like `Time.Date`, the `DateTime` module exposes functions for adding
to and updating a `DateTime`'s fields.  The functions `addYears` and
`addMonths` have the same behaviour as their `Time.Date` counterparts.

## ZonedDateTimes

`ZonedDateTimes` represent a `DateTime` in a specific `TimeZone`. See
`examples/with-timezone` for an example of how to use `ZonedDateTime`s.

``` elm
import Time.TimeZones as TimeZones
import Time.ZonedDateTime as ZonedDateTime exposing (ZonedDateTime)
```


[cal]: https://en.wikipedia.org/wiki/Proleptic_Gregorian_calendar
