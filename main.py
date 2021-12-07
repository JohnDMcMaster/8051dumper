#!/usr/bin/env python3

import argparse
import serial
import pexpect.spawnbase
import os
import time
import platform
import subprocess

class NoSuchLine(Exception):
    pass


class BadCommand(Exception):
    pass


class Timeout(Exception):
    pass


def default_port():
    '''Try to guess the serial port, if we can find a reasonable guess'''
    if platform.system() == "Linux":
        return "/dev/ttyUSB0"
    else:
        return None

class SerialExpect(pexpect.spawnbase.SpawnBase):
    '''A pexpect class that works through a serial.Serial instance.
       This is necessary for compatibility with Windows. It is basically
       a pexpect.fdpexpect, except for serial.Serial, not file descriptors.
    '''
    def __init__(self,
                 ser,
                 args=None,
                 timeout=30,
                 maxread=2000,
                 searchwindowsize=None,
                 logfile=None,
                 encoding=None,
                 codec_errors='strict',
                 use_poll=False):
        self.ser = ser
        if not isinstance(ser, serial.Serial):
            raise Exception(
                'The ser argument is not a serial.Serial instance.')
        self.args = None
        self.command = None
        pexpect.spawnbase.SpawnBase.__init__(self,
                                             timeout,
                                             maxread,
                                             searchwindowsize,
                                             logfile,
                                             encoding=encoding,
                                             codec_errors=codec_errors)
        self.child_fd = None
        self.own_fd = False
        self.closed = False
        self.name = ser.name
        self.use_poll = use_poll

    def close(self):
        self.flush()
        self.ser.close()
        self.closed = True

    def flush(self):
        self.ser.flush()

    def isalive(self):
        return not self.closed

    def terminate(self, force=False):
        raise Exception('This method is not valid for serial objects')

    def send(self, s):
        s = self._coerce_send_string(s)
        self._log(s, 'send')
        b = self._encoder.encode(s, final=False)
        self.ser.write(b)

    def sendline(self, s):
        s = self._coerce_send_string(s)
        return self.send(s + self.linesep)

    def write(self, s):
        b = self._encoder.encode(s, final=False)
        self.ser.write(b)

    def writelines(self, sequence):
        for s in sequence:
            self.write(s)

    def read(self, n):
        raise Exception()

    def read_nonblocking(self, size=1, timeout=None):
        s = self.ser.read(size)
        s = self._decoder.decode(s, final=False)
        self._log(s, 'read')
        if 0 and s:
            print("read: ", s)
            print(type(s))
        return s

def ihex2bin(ihex):
    hex_fn = "/tmp/8051dumper_tmp.hex"
    bin_fn = "/tmp/8051dumper_tmp.bin"
    try:
        open(hex_fn, "w").write(ihex)
        subprocess.check_call("objcopy --input-target=ihex --output-target=binary /tmp/8051dumper_tmp.hex /tmp/8051dumper_tmp.bin", shell=True)
        ret = open("/tmp/8051dumper_tmp.bin", "rb").read()
    finally:
        try:
            os.unlink(hex_fn)
        except:
            pass
        try:
            os.unlink(bin_fn)
        except:
            pass
    return ret


class Dumper8051:

    def __init__(self, port=None, verbose=None):
        self.timeout = 3.0
        if port is None:
            port = default_port()
            if port is None:
                raise Exception("Failed to find a serial port")
        if verbose is None:
            verbose = os.getenv("VERBOSE", "N") == "Y"
        self.verbose = verbose
        self.verbose and print("port: %s" % port)
        self.ser = serial.Serial(port,
                                 timeout=0,
                                 baudrate=9600,
                                 writeTimeout=0)
        if 0:
            while True:
                buf = self.ser.read()
                if buf:
                    print(buf)
        self.e = SerialExpect(self.ser, encoding="ascii")
        # Make sure nothing is buffered
        self.e.flush()
        self.flushInput()


    def flushInput(self):
        # Try to get rid of previous command in progress, if any
        tlast = time.time()
        while time.time() - tlast < 0.1:
            buf = self.ser.read(1024)
            if buf:
                tlast = time.time()

        self.ser.flushInput()

    def expectb(self, b, timeout=None):
        if timeout is None:
            timeout = self.timeout
        self.e.expect(b, timeout=timeout)
        return self.e.before

    def expecta(self, s, timeout=None):
        if timeout is None:
            timeout = self.timeout
        self.e.expect(bytearray(s, "ascii"), timeout=timeout)
        return self.e.before

    def readline(self, timeout=3.0):
        ret = ""
        tstart = time.time()
        while True:
            if time.time() - tstart > timeout:
                raise Timeout()
            c = self.e.read_nonblocking()
            if not c:
                continue
            if c == '\n':
                return ret
            tstart = time.time()
            ret += c

    def wait_reset(self, timeout=None):
        if timeout is None:
            timeout = 30.0
        while True:
            try:
                # self.expectb("8051dumper v1.0 by NF6X", timeout=timeout)
                l = self.readline(timeout=timeout)
                if "8051dumper v1.0 by NF6X" in l:
                    return
            except UnicodeDecodeError:
                print("WARNING: read error")

    def read_ihex(self, button_timeout=None):
        if button_timeout is None:
            button_timeout = 30.0
        print("Press red button to reset")
        self.wait_reset(timeout=button_timeout)
        print("Press green button to start")
        ihex = ""
        timeout = button_timeout
        while True:
            try:
                l = self.readline(timeout=timeout)
            except Timeout:
                if ihex:
                    print("Idle, breaking")
                    break
                else:
                    raise Exception("Timed out finding start")
            if not ihex:
                print("Found first line")
            ihex += l + "\r\n"
            # Chunks should come quickly
            timeout = 1.0
        return ihex

    def read_bin(self, button_timeout=None):
        ihex = self.read_ihex(button_timeout=button_timeout)
        return ihex2bin(ihex)


def run(fn_out, port=None, timeout=None, verbose=False):
    dumper = Dumper8051(port=port, verbose=verbose)
    buff = dumper.read_bin(button_timeout=timeout)
    open(fn_out, "wb").write(buff)


def main():
    parser = argparse.ArgumentParser(description='Decode')
    parser.add_argument('--port', default=None, help='Serial port')
    parser.add_argument('--timeout', default=30.0, help='Timeout in seconds')
    parser.add_argument('--verbose', action="store_true")
    parser.add_argument('fn_out', help='File name out')
    args = parser.parse_args()
    run(fn_out=args.fn_out, port=args.port, timeout=args.timeout, verbose=args.verbose)


if __name__ == "__main__":
    main()
