import time
class Vec:
    __slots__ = ('x', 'y')
    def __init__(self, x, y): self.x = x; self.y = y
    def AddX(self, d): self.x = self.x + d
    def Dot(self): return self.x * self.y
v = Vec(1, 3)
n = 6000000
t0 = time.perf_counter()
total = 0
for _ in range(n):
    v.AddX(1)
    total += v.Dot()
print("result: %d" % total)
print("elapsed: %d ms" % int((time.perf_counter()-t0)*1000))
