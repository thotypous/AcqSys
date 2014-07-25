import numpy as np
import sys, struct
freq=0.1
t=0
while True:
    sample = np.sin(t)
    sample = int(((1<<15) - 1) * (1 + sample))
    sys.stdout.write(struct.pack('>BH', 0b1111, sample))
    
    t += freq
    if t > 2*np.pi:
        t -= 2*np.pi    
