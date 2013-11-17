# `eventlog`

A very thin, generic Sinatra app that stores event information.

## Usage

`eventlog` allows you to send and query for event information. Inserting
data can be performed via `curl`, for example, like so:

```
$ curl -d '{"key": "test", "message": "events have keys"}' http://eventlog/events
{"status":"ok"}
```


It is important to note that `eventlog` expects valid JSON and will reject
payloads that do not fit this description with HTTP 400 status codes.

```
$ curl -v -d 'this is not JSON at all' http://eventlog/events 
HTTP/1.1 400 Bad Request 
Content-Type: application/json;charset=utf-8
Date: Fri, 15 Nov 2013 15:15:45 GMT
Server: WEBrick/1.3.1 (Ruby/2.0.0/2013-06-27)
X-Content-Type-Options: nosniff
Content-Length: 65
Connection: keep-alive

{"status":"error","message":"Received payload is not valid JSON"}
```

Querying `eventlog` is also simple:

```
$ curl http://eventlog/events
[{"id":1,"created_at":"2013-11-17 00:18:44 +0000","attrs":{"message":"events have keys"},"key":"test"}]

$ curl http://eventlog/events?since=2013-11-15
[{"id":1,"created_at":"2013-11-17 00:18:44 +0000","attrs":{"message":"events have keys"},"key":"test"}]

$ curl 'http://eventlog/events?since=2013-11-15&key=test'
[{"id":1,"created_at":"2013-11-17 00:18:44 +0000","attrs":{"message":"events have keys"},"key":"test"}]

$ curl 'http://eventlog/events?since=2013-11-15&key=some_other_key'
[]
```

## Installation
### On Heroku
1. Sign up for a [Heroku](http://www.heroku.com/) account if you don't already have one

2. Once you've completed your sign up and have set up the CLI, create an app.
    note that you will want to select the database size that is right for you.

    ```
    heroku create --addons heroku-postgresql:crane`
    git push heroku master
    ```

3. Configure the database URL

    ```
    heroku pg:wait
    heroku pg:info
    # Note the database URL presented
    heroku config:set DATABASE_URL={the URL you noted}
    ```

4. Configure a secret key

    ```
    heroku config:set SECRET_KEY=$(./scripts/gen-key)
    ```

5. Initialize the DB and restart your dynos

    ```
    heroku run sequel -E -m ./migrations \$DATABASE_URL
    heroku restart
    ```

6. That's it! Your `eventlog` app should be up now

    ```
    heroku open
    ```

