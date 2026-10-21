# bench_richards.py - Martin Richards' operating-system simulation, 500 runs of
# count = 1000. A scheduler hands packets between an idle, a worker, two handler
# and two device tasks; dominated by method calls on small objects and by
# following links between them. Each run ends with queueCount 2322, holdCount 928.
# result = runs * 10000000 + queueCount * 1000 + holdCount of the last run.
import time

ID_IDLE, ID_WORKER, ID_HANDLER_A, ID_HANDLER_B, ID_DEVICE_A, ID_DEVICE_B = range(6)
KIND_DEVICE, KIND_WORK = 0, 1
DATA_SIZE = 4


class Packet:
    __slots__ = ('link', 'id', 'kind', 'a1', 'a2')

    def __init__(self, link, id, kind):
        self.link = link
        self.id = id
        self.kind = kind
        self.a1 = 0
        self.a2 = [0] * DATA_SIZE

    # Appends this packet to the end of queue and returns the new head.
    def add_to(self, queue):
        self.link = None
        if queue is None:
            return self
        p = queue
        while p.link is not None:
            p = p.link
        p.link = self
        return queue


class Task:
    __slots__ = ('link', 'id', 'priority', 'queue', 'packet_pending', 'waiting', 'held')

    def __init__(self, id, priority, queue):
        self.link = None
        self.id = id
        self.priority = priority
        self.queue = queue
        self.packet_pending = queue is not None
        self.waiting = True
        self.held = False

    def is_held_or_waiting(self):
        return self.held or (self.waiting and not self.packet_pending)

    def run_task(self, sched):
        if self.waiting and self.packet_pending:
            packet = self.queue
            self.queue = packet.link
            self.waiting = False
            self.packet_pending = self.queue is not None
        else:
            packet = None
        return self.run(sched, packet)

    def add_packet(self, current, packet):
        if self.queue is None:
            self.queue = packet
            self.packet_pending = True
            if self.priority > current.priority:
                return self
        else:
            self.queue = packet.add_to(self.queue)
        return current


class IdleTask(Task):
    __slots__ = ('control', 'count')

    def __init__(self, id, priority, count):
        super().__init__(id, priority, None)
        self.waiting = False
        self.control = 1
        self.count = count

    def run(self, sched, packet):
        self.count -= 1
        if self.count == 0:
            return sched.hold_current()
        if self.control & 1 == 0:
            self.control >>= 1
            return sched.release(ID_DEVICE_A)
        self.control = (self.control >> 1) ^ 0xD008
        return sched.release(ID_DEVICE_B)


class WorkerTask(Task):
    __slots__ = ('dest', 'value')

    def __init__(self, id, priority, queue):
        super().__init__(id, priority, queue)
        self.dest = ID_HANDLER_A
        self.value = 0

    def run(self, sched, packet):
        if packet is None:
            return sched.suspend_current()
        self.dest = ID_HANDLER_B if self.dest == ID_HANDLER_A else ID_HANDLER_A
        packet.id = self.dest
        packet.a1 = 0
        data = packet.a2
        for i in range(DATA_SIZE):
            self.value += 1
            if self.value > 26:
                self.value = 1
            data[i] = self.value
        return sched.queue(packet)


class HandlerTask(Task):
    __slots__ = ('work', 'devices')

    def __init__(self, id, priority, queue):
        super().__init__(id, priority, queue)
        self.work = None
        self.devices = None

    def run(self, sched, packet):
        if packet is not None:
            if packet.kind == KIND_WORK:
                self.work = packet.add_to(self.work)
            else:
                self.devices = packet.add_to(self.devices)
        work = self.work
        if work is not None:
            count = work.a1
            if count < DATA_SIZE:
                dev = self.devices
                if dev is not None:
                    self.devices = dev.link
                    dev.a1 = work.a2[count]
                    work.a1 = count + 1
                    return sched.queue(dev)
            else:
                self.work = work.link
                return sched.queue(work)
        return sched.suspend_current()


class DeviceTask(Task):
    __slots__ = ('pending',)

    def __init__(self, id, priority, queue):
        super().__init__(id, priority, queue)
        self.pending = None

    def run(self, sched, packet):
        if packet is None:
            pending = self.pending
            if pending is None:
                return sched.suspend_current()
            self.pending = None
            return sched.queue(pending)
        self.pending = packet
        return sched.hold_current()


class TaskScheduler:
    __slots__ = ('tasks', 'by_id', 'current', 'queue_count', 'hold_count')

    def __init__(self):
        self.tasks = None
        self.by_id = [None] * 6
        self.current = None
        self.queue_count = 0
        self.hold_count = 0

    def add(self, task):
        task.link = self.tasks
        self.tasks = task
        self.by_id[task.id] = task

    def schedule(self):
        t = self.tasks
        while t is not None:
            if t.is_held_or_waiting():
                t = t.link
            else:
                self.current = t
                t = t.run_task(self)

    def release(self, id):
        t = self.by_id[id]
        t.held = False
        if t.priority > self.current.priority:
            return t
        return self.current

    def hold_current(self):
        self.hold_count += 1
        self.current.held = True
        return self.current.link

    def suspend_current(self):
        self.current.waiting = True
        return self.current

    def queue(self, packet):
        t = self.by_id[packet.id]
        self.queue_count += 1
        packet.link = None
        packet.id = self.current.id
        return t.add_packet(self.current, packet)


def richards(count):
    s = TaskScheduler()
    s.add(IdleTask(ID_IDLE, 0, count))
    q = Packet(None, ID_WORKER, KIND_WORK)
    q = Packet(q, ID_WORKER, KIND_WORK)
    s.add(WorkerTask(ID_WORKER, 1000, q))
    q = Packet(None, ID_DEVICE_A, KIND_DEVICE)
    q = Packet(q, ID_DEVICE_A, KIND_DEVICE)
    q = Packet(q, ID_DEVICE_A, KIND_DEVICE)
    s.add(HandlerTask(ID_HANDLER_A, 2000, q))
    q = Packet(None, ID_DEVICE_B, KIND_DEVICE)
    q = Packet(q, ID_DEVICE_B, KIND_DEVICE)
    q = Packet(q, ID_DEVICE_B, KIND_DEVICE)
    s.add(HandlerTask(ID_HANDLER_B, 3000, q))
    s.add(DeviceTask(ID_DEVICE_A, 4000, None))
    s.add(DeviceTask(ID_DEVICE_B, 5000, None))
    s.schedule()
    return s


runs = 500
t0 = time.perf_counter()
s = None
for _ in range(runs):
    s = richards(1000)
result = runs * 10000000 + s.queue_count * 1000 + s.hold_count
print("result: %d" % result)
print("elapsed: %d ms" % int((time.perf_counter()-t0)*1000))
