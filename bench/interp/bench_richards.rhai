// bench_richards.rhai - Martin Richards' operating-system simulation, 500 runs of
// count = 1000. A scheduler hands packets between an idle, a worker, two handler
// and two device tasks; dominated by method calls on small objects and by
// following links between them. Each run ends with queueCount 2322, holdCount 928.
// result = runs * 10000000 + queueCount * 1000 + holdCount of the last run.
// Rhai maps are values, not references, so the scheduler owns every task and packet
// in two arrays and a link is an index into them, -1 for none. The functions are
// methods called on the scheduler: `this` binds to it in place.
const ID_IDLE = 0;
const ID_WORKER = 1;
const ID_HANDLER_A = 2;
const ID_HANDLER_B = 3;
const ID_DEVICE_A = 4;
const ID_DEVICE_B = 5;
const KIND_DEVICE = 0;
const KIND_WORK = 1;
const DATA_SIZE = 4;

fn newPacket(link, id, kind) {
    this.packets.push(#{ link: link, id: id, kind: kind, a1: 0, a2: [0, 0, 0, 0] });
    this.packets.len() - 1
}

// Appends packet p to the end of queue and returns the new head.
fn addTo(p, queue) {
    this.packets[p].link = -1;
    if queue < 0 { return p; }
    let q = queue;
    while this.packets[q].link >= 0 { q = this.packets[q].link; }
    this.packets[q].link = p;
    queue
}

fn task(role, id, priority, queue) {
    #{ role: role, link: -1, id: id, priority: priority, queue: queue,
       packetPending: queue >= 0, waiting: true, held: false }
}

fn idleTask(id, priority, count) {
    let t = task("idle", id, priority, -1);
    t.waiting = false;
    t.control = 1;
    t.count = count;
    t
}

fn workerTask(id, priority, queue) {
    let t = task("worker", id, priority, queue);
    t.dest = global::ID_HANDLER_A;
    t.value = 0;
    t
}

fn handlerTask(id, priority, queue) {
    let t = task("handler", id, priority, queue);
    t.work = -1;
    t.devices = -1;
    t
}

fn deviceTask(id, priority, queue) {
    let t = task("device", id, priority, queue);
    t.pending = -1;
    t
}

// Called on a task, not on the scheduler.
fn isHeldOrWaiting() {
    this.held || (this.waiting && !this.packetPending)
}

fn runTask(t) {
    let packet = -1;
    if this.tasks[t].waiting && this.tasks[t].packetPending {
        packet = this.tasks[t].queue;
        this.tasks[t].queue = this.packets[packet].link;
        this.tasks[t].waiting = false;
        this.tasks[t].packetPending = this.tasks[t].queue >= 0;
    }
    switch this.tasks[t].role {
        "idle" => this.idleRun(t, packet),
        "worker" => this.workerRun(t, packet),
        "handler" => this.handlerRun(t, packet),
        "device" => this.deviceRun(t, packet),
    }
}

fn addPacket(t, current, packet) {
    if this.tasks[t].queue < 0 {
        this.tasks[t].queue = packet;
        this.tasks[t].packetPending = true;
        if this.tasks[t].priority > this.tasks[current].priority { return t; }
    } else {
        this.tasks[t].queue = this.addTo(packet, this.tasks[t].queue);
    }
    current
}

fn idleRun(t, packet) {
    this.tasks[t].count -= 1;
    if this.tasks[t].count == 0 { return this.holdCurrent(); }
    let control = this.tasks[t].control;
    if (control & 1) == 0 {
        this.tasks[t].control = control >> 1;
        return this.release(global::ID_DEVICE_A);
    }
    this.tasks[t].control = (control >> 1) ^ 0xD008;
    this.release(global::ID_DEVICE_B)
}

fn workerRun(t, packet) {
    if packet < 0 { return this.suspendCurrent(); }
    let dest = if this.tasks[t].dest == global::ID_HANDLER_A { global::ID_HANDLER_B } else { global::ID_HANDLER_A };
    this.tasks[t].dest = dest;
    this.packets[packet].id = dest;
    this.packets[packet].a1 = 0;
    for i in 0..global::DATA_SIZE {
        this.tasks[t].value += 1;
        if this.tasks[t].value > 26 { this.tasks[t].value = 1; }
        this.packets[packet].a2[i] = this.tasks[t].value;
    }
    this.queue(packet)
}

fn handlerRun(t, packet) {
    if packet >= 0 {
        if this.packets[packet].kind == global::KIND_WORK {
            this.tasks[t].work = this.addTo(packet, this.tasks[t].work);
        } else {
            this.tasks[t].devices = this.addTo(packet, this.tasks[t].devices);
        }
    }
    let work = this.tasks[t].work;
    if work >= 0 {
        let count = this.packets[work].a1;
        if count < global::DATA_SIZE {
            let dev = this.tasks[t].devices;
            if dev >= 0 {
                this.tasks[t].devices = this.packets[dev].link;
                this.packets[dev].a1 = this.packets[work].a2[count];
                this.packets[work].a1 = count + 1;
                return this.queue(dev);
            }
        } else {
            this.tasks[t].work = this.packets[work].link;
            return this.queue(work);
        }
    }
    this.suspendCurrent()
}

fn deviceRun(t, packet) {
    if packet < 0 {
        let pending = this.tasks[t].pending;
        if pending < 0 { return this.suspendCurrent(); }
        this.tasks[t].pending = -1;
        return this.queue(pending);
    }
    this.tasks[t].pending = packet;
    this.holdCurrent()
}

fn add(t) {
    t.link = this.list;
    this.list = t.id;
    this.tasks[t.id] = t;
}

fn schedule() {
    let t = this.list;
    while t >= 0 {
        if this.tasks[t].isHeldOrWaiting() {
            t = this.tasks[t].link;
        } else {
            this.current = t;
            t = this.runTask(t);
        }
    }
}

fn release(id) {
    this.tasks[id].held = false;
    let current = this.current;
    if this.tasks[id].priority > this.tasks[current].priority { return id; }
    current
}

fn holdCurrent() {
    let current = this.current;
    this.holdCount += 1;
    this.tasks[current].held = true;
    this.tasks[current].link
}

fn suspendCurrent() {
    let current = this.current;
    this.tasks[current].waiting = true;
    current
}

fn queue(packet) {
    let t = this.packets[packet].id;
    let current = this.current;
    this.queueCount += 1;
    this.packets[packet].link = -1;
    this.packets[packet].id = current;
    this.addPacket(t, current, packet)
}

fn richards(count) {
    let s = #{ tasks: [(), (), (), (), (), ()], packets: [], list: -1, current: -1,
               queueCount: 0, holdCount: 0 };
    s.add(idleTask(global::ID_IDLE, 0, count));
    let q = s.newPacket(-1, global::ID_WORKER, global::KIND_WORK);
    q = s.newPacket(q, global::ID_WORKER, global::KIND_WORK);
    s.add(workerTask(global::ID_WORKER, 1000, q));
    q = s.newPacket(-1, global::ID_DEVICE_A, global::KIND_DEVICE);
    q = s.newPacket(q, global::ID_DEVICE_A, global::KIND_DEVICE);
    q = s.newPacket(q, global::ID_DEVICE_A, global::KIND_DEVICE);
    s.add(handlerTask(global::ID_HANDLER_A, 2000, q));
    q = s.newPacket(-1, global::ID_DEVICE_B, global::KIND_DEVICE);
    q = s.newPacket(q, global::ID_DEVICE_B, global::KIND_DEVICE);
    q = s.newPacket(q, global::ID_DEVICE_B, global::KIND_DEVICE);
    s.add(handlerTask(global::ID_HANDLER_B, 3000, q));
    s.add(deviceTask(global::ID_DEVICE_A, 4000, -1));
    s.add(deviceTask(global::ID_DEVICE_B, 5000, -1));
    s.schedule();
    s
}

let runs = 500;
let t0 = timestamp();
let s = ();
for r in 0..runs { s = richards(1000); }
let elapsed = (t0.elapsed * 1000.0).to_int();
print("result: " + (runs * 10000000 + s.queueCount * 1000 + s.holdCount));
print("elapsed: " + elapsed + " ms");
