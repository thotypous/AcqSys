import sys, struct, random
import numpy as np
from matplotlib.pylab import find
NumChannels = 6
MaxCyclesOfSimulation = 1e5
SkipCycles = 300
CyclesResolution = 20
MinStimSyncPeriod = 60

if len(sys.argv) != 1 + NumChannels:
    sys.stderr.write('usage: %s ch0_period ch1_period ... ch%d_period\n' % (sys.argv[0], NumChannels-1))
    sys.exit(1)
periods = map(float, sys.argv[1:])
freqs = [1./period for period in periods]
delta_t = np.array([int(random.expovariate(freq)) for freq in freqs], dtype=np.uint32)
t = SkipCycles
while True:
    min_t = delta_t.min()
    t += min_t
    if t > MaxCyclesOfSimulation:
        break
    delta_t -= min_t
    indices = find(delta_t == 0)
    flag = 0
    for ch in indices:
        flag |= (1 << ch)
        if ch == 0:
            delta_t[ch] = max(MinStimSyncPeriod, random.normalvariate(periods[ch], 0.1*periods[ch]))
        else:
            delta_t[ch] = max(CyclesResolution, int(random.expovariate(freqs[ch])))
    #sys.stderr.write("flag=%s timestamp=%u\n" % (bin(flag)[2:].rjust(8,'0'), t))
    sys.stdout.write(struct.pack('>BL', flag, t))
