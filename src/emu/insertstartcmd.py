import sys

if len(sys.argv) != 2:
    sys.stderr.write('usage: %s after_reqs\n' % (sys.argv[0]))
    sys.exit(1)
    
after_reqs = int(sys.argv[1])
sys.stdout.write(sys.stdin.read(3*after_reqs))
sys.stdout.write('\x80')  # start cmd
# just copy from now on
while True: 
    data = sys.stdin.read(3*1024)
    if data == '':
        break
    sys.stdout.write(data)