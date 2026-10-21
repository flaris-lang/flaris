// bench_richards.js - Martin Richards' operating-system simulation, 500 runs of
// count = 1000. A scheduler hands packets between an idle, a worker, two handler
// and two device tasks; dominated by method calls on small objects and by
// following links between them. Each run ends with queueCount 2322, holdCount 928.
// result = runs * 10000000 + queueCount * 1000 + holdCount of the last run.
const ID_IDLE = 0, ID_WORKER = 1, ID_HANDLER_A = 2, ID_HANDLER_B = 3, ID_DEVICE_A = 4, ID_DEVICE_B = 5;
const KIND_DEVICE = 0, KIND_WORK = 1;
const DATA_SIZE = 4;

class Packet {
    constructor(link, id, kind) {
        this.link = link;
        this.id = id;
        this.kind = kind;
        this.a1 = 0;
        this.a2 = [0, 0, 0, 0];
    }
    // Appends this packet to the end of queue and returns the new head.
    addTo(queue) {
        this.link = null;
        if (queue === null) return this;
        let p = queue;
        while (p.link !== null) p = p.link;
        p.link = this;
        return queue;
    }
}

class Task {
    constructor(id, priority, queue) {
        this.link = null;
        this.id = id;
        this.priority = priority;
        this.queue = queue;
        this.packetPending = queue !== null;
        this.waiting = true;
        this.held = false;
    }
    isHeldOrWaiting() {
        return this.held || (this.waiting && !this.packetPending);
    }
    runTask(s) {
        let packet = null;
        if (this.waiting && this.packetPending) {
            packet = this.queue;
            this.queue = packet.link;
            this.waiting = false;
            this.packetPending = this.queue !== null;
        }
        return this.run(s, packet);
    }
    addPacket(current, packet) {
        if (this.queue === null) {
            this.queue = packet;
            this.packetPending = true;
            if (this.priority > current.priority) return this;
        } else {
            this.queue = packet.addTo(this.queue);
        }
        return current;
    }
}

class IdleTask extends Task {
    constructor(id, priority, count) {
        super(id, priority, null);
        this.waiting = false;
        this.control = 1;
        this.count = count;
    }
    run(s, packet) {
        this.count--;
        if (this.count === 0) return s.holdCurrent();
        if ((this.control & 1) === 0) {
            this.control = this.control >> 1;
            return s.release(ID_DEVICE_A);
        }
        this.control = (this.control >> 1) ^ 0xD008;
        return s.release(ID_DEVICE_B);
    }
}

class WorkerTask extends Task {
    constructor(id, priority, queue) {
        super(id, priority, queue);
        this.dest = ID_HANDLER_A;
        this.value = 0;
    }
    run(s, packet) {
        if (packet === null) return s.suspendCurrent();
        this.dest = this.dest === ID_HANDLER_A ? ID_HANDLER_B : ID_HANDLER_A;
        packet.id = this.dest;
        packet.a1 = 0;
        const data = packet.a2;
        for (let i = 0; i < DATA_SIZE; i++) {
            this.value++;
            if (this.value > 26) this.value = 1;
            data[i] = this.value;
        }
        return s.queue(packet);
    }
}

class HandlerTask extends Task {
    constructor(id, priority, queue) {
        super(id, priority, queue);
        this.work = null;
        this.devices = null;
    }
    run(s, packet) {
        if (packet !== null) {
            if (packet.kind === KIND_WORK) this.work = packet.addTo(this.work);
            else this.devices = packet.addTo(this.devices);
        }
        const work = this.work;
        if (work !== null) {
            const count = work.a1;
            if (count < DATA_SIZE) {
                const dev = this.devices;
                if (dev !== null) {
                    this.devices = dev.link;
                    dev.a1 = work.a2[count];
                    work.a1 = count + 1;
                    return s.queue(dev);
                }
            } else {
                this.work = work.link;
                return s.queue(work);
            }
        }
        return s.suspendCurrent();
    }
}

class DeviceTask extends Task {
    constructor(id, priority, queue) {
        super(id, priority, queue);
        this.pending = null;
    }
    run(s, packet) {
        if (packet === null) {
            const pending = this.pending;
            if (pending === null) return s.suspendCurrent();
            this.pending = null;
            return s.queue(pending);
        }
        this.pending = packet;
        return s.holdCurrent();
    }
}

class TaskScheduler {
    constructor() {
        this.tasks = null;
        this.byId = [null, null, null, null, null, null];
        this.current = null;
        this.queueCount = 0;
        this.holdCount = 0;
    }
    add(t) {
        t.link = this.tasks;
        this.tasks = t;
        this.byId[t.id] = t;
    }
    schedule() {
        let t = this.tasks;
        while (t !== null) {
            if (t.isHeldOrWaiting()) {
                t = t.link;
            } else {
                this.current = t;
                t = t.runTask(this);
            }
        }
    }
    release(id) {
        const t = this.byId[id];
        t.held = false;
        if (t.priority > this.current.priority) return t;
        return this.current;
    }
    holdCurrent() {
        this.holdCount++;
        this.current.held = true;
        return this.current.link;
    }
    suspendCurrent() {
        this.current.waiting = true;
        return this.current;
    }
    queue(packet) {
        const t = this.byId[packet.id];
        this.queueCount++;
        packet.link = null;
        packet.id = this.current.id;
        return t.addPacket(this.current, packet);
    }
}

function richards(count) {
    const s = new TaskScheduler();
    s.add(new IdleTask(ID_IDLE, 0, count));
    let q = new Packet(null, ID_WORKER, KIND_WORK);
    q = new Packet(q, ID_WORKER, KIND_WORK);
    s.add(new WorkerTask(ID_WORKER, 1000, q));
    q = new Packet(null, ID_DEVICE_A, KIND_DEVICE);
    q = new Packet(q, ID_DEVICE_A, KIND_DEVICE);
    q = new Packet(q, ID_DEVICE_A, KIND_DEVICE);
    s.add(new HandlerTask(ID_HANDLER_A, 2000, q));
    q = new Packet(null, ID_DEVICE_B, KIND_DEVICE);
    q = new Packet(q, ID_DEVICE_B, KIND_DEVICE);
    q = new Packet(q, ID_DEVICE_B, KIND_DEVICE);
    s.add(new HandlerTask(ID_HANDLER_B, 3000, q));
    s.add(new DeviceTask(ID_DEVICE_A, 4000, null));
    s.add(new DeviceTask(ID_DEVICE_B, 5000, null));
    s.schedule();
    return s;
}

const runs = 500;
const t0 = Date.now();
let s = null;
for (let r = 0; r < runs; r++) s = richards(1000);
const elapsed = Date.now() - t0;
console.log("result: " + (runs * 10000000 + s.queueCount * 1000 + s.holdCount));
console.log("elapsed: " + elapsed + " ms");
