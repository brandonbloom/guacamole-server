# VNC: `size` before the VNC connection exists crashes guacd

guacd 1.6.0 (and `main` as of ae12b8e5) crashes the connection process
when the client sends a `size` instruction while the VNC connection is
still being established, for example while guacd waits for credentials it
requested with `required`. `guac_vnc_user_size_handler()` passes
`vnc_client->rfb_client`, still NULL, to `guac_vnc_display_set_size()`,
whose first call, `rfbClientGetClientData()`, dereferences it.

A phone triggers it reliably: focusing the password prompt opens the
on-screen keyboard, the viewport shrinks, and the client sends `size`.

This directory reproduces it without a VNC server or the web application:
`repro.py` runs a stub VNC server that requires a VNC password and then
waits, and speaks the Guacamole protocol directly to guacd.

## Steps

```sh
docker compose -p guacrepro up --abort-on-container-exit --exit-code-from repro
docker compose -p guacrepro down
```

Output with `guacamole/guacd:1.6.0`:

```
guacd: ['ready', '$…']
stub VNC server: 172.18.0.2 is in the credentials stage
guacd: ['required', 'password']
client: sending size 390x500 while guacd waits for the password
✗ guacd closed the connection 1.1s after connecting (after the size instruction)
```

guacd logs `Connection "$…" removed.` and `Unable to request termination
of client process: No such process`: the connection process died.

Controls, both of which stay connected for 10 seconds:

```sh
REPRO_ARGS=--no-size docker compose -p guacrepro up --abort-on-container-exit --exit-code-from repro
REPRO_ARGS=--disable-display-resize docker compose -p guacrepro up --abort-on-container-exit --exit-code-from repro
```

To test another guacd build, set `GUACD_IMAGE`, or run `repro.py` against
any guacd: `python3 repro.py GUACD_HOST --stub-host ADDRESS_GUACD_REACHES_THIS_HOST_AT --stub-port 5999`.
