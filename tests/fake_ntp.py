#!/usr/bin/env python3
"""fake_ntp.py - an SNTP server on a UDP socket, for tests/test_ntp.fls.

Binds 127.0.0.1 on a free port, prints the port number on stdout as its first
line, then answers every 48-byte NTP request with a stratum-2 server reply
(LI=0, VN=4, mode=4) whose originate timestamp echoes the client's transmit,
so the offset math in the library is exercised against a real socket without
needing internet access or --unsafe. Serves until its stdin closes (or until
killed, when stdin is a terminal); test_ntp.fls starts it with a pipe for
stdin, so the fake never outlives the test.
"""

import os
import select
import socket
import sys
import time

NTP_UNIX_OFFSET = 2208988800  # seconds between 1900-01-01 and 1970-01-01


def ntp_now():
    t = time.time() + NTP_UNIX_OFFSET
    secs = int(t)
    frac = int((t - secs) * 4294967296) & 0xFFFFFFFF
    return secs, frac


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("127.0.0.1", 0))
    sock.setblocking(False)
    print(sock.getsockname()[1], flush=True)

    watch = [sock] if os.isatty(0) else [sock, 0]
    while True:
        ready, _, _ = select.select(watch, [], [], 0.5)
        if 0 in ready and not os.read(0, 4096):
            break
        if sock not in ready:
            continue
        try:
            data, addr = sock.recvfrom(1024)
        except BlockingIOError:
            continue
        if len(data) < 48:
            continue
        s_ref, f_ref = ntp_now()
        s_tx, f_tx = ntp_now()
        resp = bytearray(48)
        resp[0] = 0x24          # LI=0, VN=4, mode=4 (server)
        resp[1] = 2             # stratum 2
        resp[2] = 6             # poll
        resp[3] = 0xEC          # precision ~ -20
        resp[12:16] = b"LOCL"   # reference id

        def put(off, s, f):
            resp[off:off + 4] = s.to_bytes(4, "big")
            resp[off + 4:off + 8] = f.to_bytes(4, "big")

        put(16, s_ref, f_ref)       # reference timestamp
        resp[24:32] = data[40:48]   # originate = client's transmit
        put(32, s_ref, f_ref)       # receive timestamp
        put(40, s_tx, f_tx)         # transmit timestamp
        # The request's version picks a bad reply, for the validation tests:
        # 3 kiss-o'-death, 2 unsynchronised, 1 originate that is not ours.
        vn = (data[0] >> 3) & 7
        if vn == 3:
            resp[1] = 0
            resp[12:16] = b"RATE"
        elif vn == 2:
            resp[0] = 0xE4      # LI=3: clock not synchronised
        elif vn == 1:
            resp[24:32] = bytes(8)
        sock.sendto(bytes(resp), addr)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
