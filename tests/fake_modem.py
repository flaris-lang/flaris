#!/usr/bin/env python3
"""fake_modem.py - an AT-command responder on a pseudo-terminal.

Stream.OpenSerial cannot tell this from a real modem, so tests/test_modem.fls
drives the whole library - including the parts that only misbehave against a
device - without hardware and without --unsafe.

Prints the slave tty path on stdout as its first line, then serves until its
stdin closes (or until it is killed, when stdin is a terminal). test_modem.fls
starts it with a pipe for stdin and reads that first line, so the fake never
outlives the test.

Answers are deliberately awkward where a real modem is awkward: +CSQ arrives
split across two writes (a line routinely lands in two reads on a real port),
AT+AWKWARD stays silent so a timeout can be tested, and an unsolicited +QIND
is injected mid-command so URC handling is exercised against a reply in flight.
"""

import os
import pty
import select
import sys
import termios
import time
import tty

# command -> response body lines (the trailing OK is added unless noted)
REPLIES = {
    "AT":          [],
    "ATE0":        [],
    "AT+CMEE=2":   [],
    "AT+CGMI":     ["Quectel"],
    "AT+CGMM":     ["EG25-G"],
    "AT+CGMR":     ["EG25GGBR07A08M2G"],
    "AT+CGSN":     ["867698040000001"],
    "AT+CIMI":     ["240080000000001"],
    "AT+CPIN?":    ["+CPIN: READY"],
    "AT+QCCID":    ["+QCCID: 89460800000000000000"],
    "AT+CSQ":      ["+CSQ: 23,99"],
    "AT+COPS?":    ['+COPS: 0,0,"Telia",7'],
    "AT+CREG?":    ["+CREG: 0,1"],
    "AT+CNUM":     ['+CNUM: "","+46701234567",145'],
}


def respond(fd, cmd):
    """Write the reply for one command, in the shape a real modem uses."""
    if cmd == "AT+AWKWARD":
        return                                    # silent: the caller must time out
    if cmd == "AT+SLOW":
        # answers late, so a cancel reliably lands while the reply is still
        # owed and the next command has to read past it.
        time.sleep(0.4)
        os.write(fd, b"\r\n+SLOW: 1\r\n\r\nOK\r\n")
        return
    if cmd == "AT+FAIL":
        os.write(fd, b"\r\nERROR\r\n")
        return
    if cmd == "AT+CMEFAIL":
        os.write(fd, b"\r\n+CME ERROR: SIM not inserted\r\n")
        return
    if cmd == "AT+URCMID":
        # a URC racing a reply: unsolicited line first, then this command's own.
        # +QIND is used rather than +CMTI because Modem itself already claims
        # +CMTI, and URC dispatch is first-match-wins - a test handler for a
        # prefix the library owns would never fire.
        os.write(fd, b"\r\n+QIND: \"act\",\"LTE\"\r\n")
        time.sleep(0.02)
        os.write(fd, b"\r\n+MID: 1\r\n\r\nOK\r\n")
        return
    if cmd == "AT+CSQ":
        # the classic split line: half now, half a beat later
        os.write(fd, b"\r\n+CSQ: 23,")
        time.sleep(0.03)
        os.write(fd, b"99\r\n\r\nOK\r\n")
        return
    if cmd in REPLIES:
        for line in REPLIES[cmd]:
            os.write(fd, ("\r\n" + line + "\r\n").encode())
        os.write(fd, b"\r\nOK\r\n")
        return
    os.write(fd, b"\r\nERROR\r\n")


def main():
    master, slave = pty.openpty()
    # Raw on both ends: the default line discipline is canonical and echoing,
    # which would bounce every command back at the caller and hold replies
    # until a newline. A real serial port does neither, and Stream.OpenSerial
    # opens its end raw, so the pty has to match or the framing tests are
    # testing the tty driver rather than the library.
    tty.setraw(master, termios.TCSANOW)
    tty.setraw(slave, termios.TCSANOW)
    os.set_blocking(master, False)
    print(os.ttyname(slave), flush=True)

    watch = [master] if os.isatty(0) else [master, 0]
    buf = b""
    while True:
        ready, _, _ = select.select(watch, [], [])
        if 0 in ready and not os.read(0, 4096):
            break
        if master not in ready:
            continue
        try:
            chunk = os.read(master, 4096)
        except BlockingIOError:
            continue
        except OSError:
            break
        if not chunk:
            time.sleep(0.005)
            continue
        buf += chunk
        while b"\r" in buf:
            line, buf = buf.split(b"\r", 1)
            cmd = line.decode(errors="replace").strip()
            if cmd:
                respond(master, cmd)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
