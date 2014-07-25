import numpy as np
import sys, struct, random
y=0
while True:
    y += int((1<<10)*(1.-2.*random.random()))
    if y < 0: y = 0
    if y > (1<<16)-1: y = (1<<16)-1
    sys.stdout.write(struct.pack('>BH', 0b1111, y))