# Diagrams — Chapter 7, The Sleeping-Barber Problem

All diagrams are Mermaid and render directly in the VS Code Markdown preview
(`Ctrl+Shift+V`) and on GitHub.

---

## 1. System architecture

```mermaid
graph TB
    subgraph APP["main.c — Chapter 7 application (RT-Thread threads)"]
        B["barber_thread<br/>priority 10<br/>stack 20 KB"]
        C1["customer_thread #1<br/>priority 5"]
        C2["customer_thread #2<br/>priority 6"]
        C3["customer_thread #3<br/>priority 7"]
        C4["customer_thread #4<br/>priority 8"]
        C5["customer_thread #5<br/>priority 9"]
    end

    subgraph IPC["RT-Thread IPC objects"]
        S1(["customers<br/>counting semaphore<br/>value 0"])
        S2(["barber<br/>counting semaphore<br/>value 0"])
        M{{"mutex / seatmutex<br/>value 1"}}
        F["freeseats<br/>unsigned char = 3<br/>(N chairs)"]
    end

    B -->|"P(customers)"| S1
    B -->|"V(barber)"| S2
    B -->|"P / V"| M
    B -->|"freeseats++"| F

    C1 --> S1
    C2 --> S1
    C3 --> S1
    C4 --> S1
    C5 --> S1

    C1 -->|"P(barber)"| S2
    C1 -->|"P / V"| M
    C1 -->|"freeseats--"| F

    subgraph KERNEL["RT-Thread 4.0.2 kernel + LS1B port (RTT4/)"]
        SCHED["priority preemptive scheduler<br/>RT_TICK_PER_SECOND = 1000"]
        HEAP["heap<br/>RT_USING_HEAP"]
        CON["rt_kprintf → console<br/>UART5, 115200 8-N-1"]
    end

    SCHED --> APP
    CON --> UART5(["PuTTY / serial terminal"])
```

---

## 2. Barber state machine

```mermaid
stateDiagram-v2
    [*] --> Sleeping
    Sleeping --> Waking : customer executes V(customers)<br/>(P(customers) returns)
    Waking --> Cutting : P(mutex), freeseats++,<br/>V(barber), V(mutex)
    Cutting --> Sleeping : "barber finish cut hair."<br/>loop back to P(customers)
    Cutting --> Cutting : next customer already<br/>counted in `customers`
```

---

## 3. Customer lifecycle

```mermaid
stateDiagram-v2
    [*] --> Arriving
    Arriving --> Deciding : after rt_thread_mdelay(50)<br/>P(mutex)
    Deciding --> Seated : freeseats > 0<br/>freeseats--<br/>V(customers)<br/>V(mutex)
    Deciding --> Leaving : freeseats == 0<br/>"customers N leave."<br/>V(mutex)
    Seated --> Waiting : P(barber)
    Waiting --> Haircut : barber executes V(barber)
    Haircut --> [*] : thread entry returns,<br/>RT-Thread deletes the thread
    Leaving --> [*]
```

---

## 4. Timeline of the guide's demonstration (5 customers, 3 chairs)

```mermaid
sequenceDiagram
    autonumber
    participant M as main (prio 10)
    participant C as customers 1..5 (prio 5..9)
    participant B as barber (prio 10)
    participant U as UART5 console

    M->>U: create semaphore barber / customers / mutex
    M->>B: rt_thread_create + rt_thread_startup
    B->>B: P(customers) → blocks (value 0) = SLEEPING
    M->>C: create + start 5 customer threads
    Note over C: every customer waits rt_thread_mdelay(50)

    C->>C: customer 1..3 take the mutex one after another
    C->>U: freeseats=2 / freeseats=1 / freeseats=0
    C->>U: customers 1..3 is waitting to cut hair.
    C->>B: V(customers) ×3
    C->>C: customer 4, 5 find freeseats == 0
    C->>U: customers 4 leave. / customers 5 leave.
    C->>C: customers 1..3 block in P(barber)

    B->>B: P(customers) returns → wakes up
    B->>U: barber find customer 0 .
    B->>B: P(mutex), freeseats++, V(barber), V(mutex)
    B->>U: barber begin to cut hair.
    B->>B: rt_thread_mdelay(40)
    B->>U: barber finish cut hair.
    Note over B: loop repeats for customer 1 and 2,<br/>then P(customers) blocks again → SLEEPING
```

---

## 5. Why no deadlock and no starvation

```mermaid
flowchart LR
    A["customer holds mutex<br/>freeseats-- and V(customers)"] --> B["mutex released<br/>BEFORE P(barber)"]
    B --> C["barber can always take<br/>P(mutex) after P(customers)"]
    C --> D["barber executes V(barber)<br/>for every P(customers)"]
    D --> E["no customer can wait<br/>forever for the barber"]
    E --> F["+ 1 mutex → the critical<br/>section has a single owner"]
    F --> G["no lost update on freeseats"]
```
