#!/usr/bin/env python
import sys
import atexit
import os

if os.name == 'nt':
    import msvcrt
else:
    import termios

orig_term = None

##################################################################
# stdio_init
##################################################################
def stdio_init():
    if os.name == 'nt':
        pass
    else:
        atexit.register(stdio_close)
        global orig_term
        orig_term = termios.tcgetattr(sys.stdin)
        new_settings = termios.tcgetattr(sys.stdin)
        new_settings[3] = new_settings[3] & ~(termios.ECHO | termios.ICANON)
        new_settings[6][termios.VMIN] = 0
        new_settings[6][termios.VTIME] = 0
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, new_settings)

##################################################################
# stdio_close
##################################################################
def stdio_close():
    if os.name != 'nt':
        global orig_term
        if orig_term:
            termios.tcsetattr(sys.stdin, termios.TCSADRAIN, orig_term)

##################################################################
# stdio_read
##################################################################
def stdio_read():
    if os.name == 'nt':
        if msvcrt.kbhit():
            ch = msvcrt.getch()
            return ch
        else:
            return None
    else:
        ch = os.read(sys.stdin.fileno(), 1)
        if len(ch) > 0:
            return ch
        else:
            return None
