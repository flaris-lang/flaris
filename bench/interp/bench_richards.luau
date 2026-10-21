-- bench_richards.luau - Martin Richards' operating-system simulation, 500 runs of
-- count = 1000. A scheduler hands packets between an idle, a worker, two handler
-- and two device tasks; dominated by method calls on small objects and by
-- following links between them. Each run ends with queueCount 2322, holdCount 928.
-- result = runs * 10000000 + queueCount * 1000 + holdCount of the last run.
local ID_IDLE, ID_WORKER, ID_HANDLER_A, ID_HANDLER_B, ID_DEVICE_A, ID_DEVICE_B = 1, 2, 3, 4, 5, 6
local KIND_DEVICE, KIND_WORK = 0, 1
local DATA_SIZE = 4

-- Lua 5.1 syntax has no xor operator: use the bit library where there is one
-- (Luau, LuaJIT), else compile the 5.3+ operator.
local bxor = (bit32 and bit32.bxor) or (bit and bit.bxor)
    or load("return function(a, b) return a ~ b end")()

local Packet = {}
Packet.__index = Packet

function Packet.new(link, id, kind)
    return setmetatable({link = link, id = id, kind = kind, a1 = 0, a2 = {0, 0, 0, 0}}, Packet)
end

-- Appends this packet to the end of queue and returns the new head.
function Packet:addTo(queue)
    self.link = nil
    if queue == nil then return self end
    local p = queue
    while p.link ~= nil do p = p.link end
    p.link = self
    return queue
end

local Task = {}
Task.__index = Task

function Task.init(self, id, priority, queue)
    self.link = nil
    self.id = id
    self.priority = priority
    self.queue = queue
    self.packetPending = queue ~= nil
    self.waiting = true
    self.held = false
    return self
end

function Task:isHeldOrWaiting()
    return self.held or (self.waiting and not self.packetPending)
end

function Task:runTask(s)
    local packet = nil
    if self.waiting and self.packetPending then
        packet = self.queue
        self.queue = packet.link
        self.waiting = false
        self.packetPending = self.queue ~= nil
    end
    return self:run(s, packet)
end

function Task:addPacket(current, packet)
    if self.queue == nil then
        self.queue = packet
        self.packetPending = true
        if self.priority > current.priority then return self end
    else
        self.queue = packet:addTo(self.queue)
    end
    return current
end

local function subclass(base)
    local c = setmetatable({}, {__index = base})
    c.__index = c
    return c
end

local IdleTask = subclass(Task)

function IdleTask.new(id, priority, count)
    local t = Task.init(setmetatable({}, IdleTask), id, priority, nil)
    t.waiting = false
    t.control = 1
    t.count = count
    return t
end

function IdleTask:run(s, packet)
    self.count = self.count - 1
    if self.count == 0 then return s:holdCurrent() end
    if self.control % 2 == 0 then
        self.control = math.floor(self.control / 2)
        return s:release(ID_DEVICE_A)
    end
    self.control = bxor(math.floor(self.control / 2), 0xD008)
    return s:release(ID_DEVICE_B)
end

local WorkerTask = subclass(Task)

function WorkerTask.new(id, priority, queue)
    local t = Task.init(setmetatable({}, WorkerTask), id, priority, queue)
    t.dest = ID_HANDLER_A
    t.value = 0
    return t
end

function WorkerTask:run(s, packet)
    if packet == nil then return s:suspendCurrent() end
    if self.dest == ID_HANDLER_A then self.dest = ID_HANDLER_B else self.dest = ID_HANDLER_A end
    packet.id = self.dest
    packet.a1 = 0
    local data = packet.a2
    for i = 1, DATA_SIZE do
        self.value = self.value + 1
        if self.value > 26 then self.value = 1 end
        data[i] = self.value
    end
    return s:queue(packet)
end

local HandlerTask = subclass(Task)

function HandlerTask.new(id, priority, queue)
    local t = Task.init(setmetatable({}, HandlerTask), id, priority, queue)
    t.work = nil
    t.devices = nil
    return t
end

function HandlerTask:run(s, packet)
    if packet ~= nil then
        if packet.kind == KIND_WORK then
            self.work = packet:addTo(self.work)
        else
            self.devices = packet:addTo(self.devices)
        end
    end
    local work = self.work
    if work ~= nil then
        local count = work.a1
        if count < DATA_SIZE then
            local dev = self.devices
            if dev ~= nil then
                self.devices = dev.link
                dev.a1 = work.a2[count + 1]
                work.a1 = count + 1
                return s:queue(dev)
            end
        else
            self.work = work.link
            return s:queue(work)
        end
    end
    return s:suspendCurrent()
end

local DeviceTask = subclass(Task)

function DeviceTask.new(id, priority, queue)
    local t = Task.init(setmetatable({}, DeviceTask), id, priority, queue)
    t.pending = nil
    return t
end

function DeviceTask:run(s, packet)
    if packet == nil then
        local pending = self.pending
        if pending == nil then return s:suspendCurrent() end
        self.pending = nil
        return s:queue(pending)
    end
    self.pending = packet
    return s:holdCurrent()
end

local TaskScheduler = {}
TaskScheduler.__index = TaskScheduler

function TaskScheduler.new()
    return setmetatable({tasks = nil, byId = {}, current = nil, queueCount = 0, holdCount = 0}, TaskScheduler)
end

function TaskScheduler:add(t)
    t.link = self.tasks
    self.tasks = t
    self.byId[t.id] = t
end

function TaskScheduler:schedule()
    local t = self.tasks
    while t ~= nil do
        if t:isHeldOrWaiting() then
            t = t.link
        else
            self.current = t
            t = t:runTask(self)
        end
    end
end

function TaskScheduler:release(id)
    local t = self.byId[id]
    t.held = false
    if t.priority > self.current.priority then return t end
    return self.current
end

function TaskScheduler:holdCurrent()
    self.holdCount = self.holdCount + 1
    self.current.held = true
    return self.current.link
end

function TaskScheduler:suspendCurrent()
    self.current.waiting = true
    return self.current
end

function TaskScheduler:queue(packet)
    local t = self.byId[packet.id]
    self.queueCount = self.queueCount + 1
    packet.link = nil
    packet.id = self.current.id
    return t:addPacket(self.current, packet)
end

local function richards(count)
    local s = TaskScheduler.new()
    s:add(IdleTask.new(ID_IDLE, 0, count))
    local q = Packet.new(nil, ID_WORKER, KIND_WORK)
    q = Packet.new(q, ID_WORKER, KIND_WORK)
    s:add(WorkerTask.new(ID_WORKER, 1000, q))
    q = Packet.new(nil, ID_DEVICE_A, KIND_DEVICE)
    q = Packet.new(q, ID_DEVICE_A, KIND_DEVICE)
    q = Packet.new(q, ID_DEVICE_A, KIND_DEVICE)
    s:add(HandlerTask.new(ID_HANDLER_A, 2000, q))
    q = Packet.new(nil, ID_DEVICE_B, KIND_DEVICE)
    q = Packet.new(q, ID_DEVICE_B, KIND_DEVICE)
    q = Packet.new(q, ID_DEVICE_B, KIND_DEVICE)
    s:add(HandlerTask.new(ID_HANDLER_B, 3000, q))
    s:add(DeviceTask.new(ID_DEVICE_A, 4000, nil))
    s:add(DeviceTask.new(ID_DEVICE_B, 5000, nil))
    s:schedule()
    return s
end

local runs = 500
local t0 = os.clock()
local s
for _ = 1, runs do s = richards(1000) end
local elapsed = math.floor((os.clock() - t0) * 1000)
print("result: " .. (runs * 10000000 + s.queueCount * 1000 + s.holdCount))
print("elapsed: " .. elapsed .. " ms")
