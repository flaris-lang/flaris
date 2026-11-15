#!/usr/bin/env python3
"""fake_gps.py - an NMEA 0183 emitter on a pseudo-terminal.

Stream.OpenSerial cannot tell this from a real GPS receiver, so
tests/test_gps.fls drives the whole library - including a sentence split
across two writes and a bad-checksum sentence that must be dropped - without
hardware and without --unsafe.

Prints the slave tty path on stdout as its first line, then emits a fixed
round of NMEA sentences (checksums computed, not hardcoded) on every beat
until its stdin closes (or until it is killed, when stdin is a terminal).
tests/test_gps.fls starts it with a pipe for stdin and reads that first line,
so the fake never outlives the test.
"""

import os
import pty
import select
import sys
import termios
import time
import tty


def nmea(body):
    x = 0
    for ch in body.encode():
        x ^= ch
    return "$%s*%02X\r\n" % (body, x)


# One round of sentences, in the order a receiver would emit them.
ROUND = [
    "GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,",
    "GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W,A",
    "GPGSA,A,3,04,05,,09,12,,,,,,,,2.5,1.3,2.1",
    "GPGSV,2,1,08,01,40,083,41,02,17,308,42,12,07,344,39,14,15,270,40",
    "GPGSV,2,2,08,22,62,180,45,25,30,120,,",
    "GPVTG,084.4,T,081.3,M,022.4,N,041.5,K,A",
    "GPGLL,4807.038,N,01131.000,E,123519,A,A",
    "GPZDA,123519,23,03,1994,00,00",
    "PMTK001,314,3",
]

# Right sentence, wrong checksum: the library must drop it.
BAD = "$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*00\r\n"

# A good sentence that arrives in two writes, like a line on a real port.
SPLIT = nmea("GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W,A")


def main():
    master, slave = pty.openpty()
    # Raw on both ends: the default line discipline is canonical and echoing,
    # which would bounce bytes back at the caller and hold writes until a
    # newline. A real serial port does neither, and Stream.OpenSerial opens
    # its end raw, so the pty has to match or the framing tests are testing
    # the tty driver rather than the library.
    tty.setraw(master, termios.TCSANOW)
    tty.setraw(slave, termios.TCSANOW)
    os.set_blocking(master, False)
    print(os.ttyname(slave), flush=True)

    watch = [master] if os.isatty(0) else [master, 0]
    while True:
        ready, _, _ = select.select(watch, [], [], 0.2)
        if 0 in ready and not os.read(0, 4096):
            break
        if master in ready:
            # drain anything the VM wrote, so the pty buffer never fills
            try:
                while os.read(master, 4096):
                    pass
            except (BlockingIOError, OSError):
                pass
        for body in ROUND:
            os.write(master, nmea(body).encode())
            time.sleep(0.01)
        os.write(master, BAD.encode())
        half = len(SPLIT) // 2
        os.write(master, SPLIT[:half].encode())
        time.sleep(0.03)
        os.write(master, SPLIT[half:].encode())


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
