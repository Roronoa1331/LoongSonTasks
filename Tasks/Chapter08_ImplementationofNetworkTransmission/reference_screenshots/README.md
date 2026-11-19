# Reference screenshots — expected appearance only (NOT experiment results)

These eight images are the figures of the course guide itself
(`Computer_System_Comprehensive_Design_Experiment_Guide_EN.doc`, chapter 8,
Figures 8.5 – 8.12). They were extracted from the `.docx` package and are kept
here so that the expected look of every window is available while working — and
so that they can never be mistaken for evidence produced in this laboratory.

> **They were produced by the course author on another machine
> (RT-Thread 4.0.3, build of 2022-03-02, `COM8`). They are reference material
> only: they are not proof of any experiment in this project and must not be
> cited in the report as a result.**

## What each file shows

| File | Guide figure | Window / content |
|---|---|---|
| `manual_fig8.5_tcp_server_netassist.png` | 8.5 | NetAssist **TCP Client**, remote `192.168.1.123:9060` — experiment A, PC side |
| `manual_fig8.6_tcp_server_putty.png` | 8.6 | PuTTY console of the board for experiment A: `succeed to listen!`, `client incoming succeed!`, `RECEIVE:`/`SEND:` |
| `manual_fig8.7_tcp_client_netassist.png` | 8.7 | NetAssist **TCP Server**, local `192.168.1.111:9061` — experiment B, PC side |
| `manual_fig8.8_tcp_client_putty.png` | 8.8 | PuTTY console for experiment B: `succeed to connect to server!`, five `SEND:`/`RECEIVE:` pairs, `tcp_client_thread stop!` |
| `manual_fig8.9_udp_server_netassist.png` | 8.9 | NetAssist **UDP**, local port `9062`, remote `192.168.1.123:9062` — experiment C, PC side |
| `manual_fig8.10_udp_server_putty.png` | 8.10 | PuTTY console for experiment C: `succeed to bind ip!`, `RECEIVE:`/`SEND:` |
| `manual_fig8.11_udp_client_netassist.png` | 8.11 | NetAssist **UDP**, local port `9063`, receiving `client ticks = ...` — experiment D, PC side |
| `manual_fig8.12_udp_client_putty.png` | 8.12 | PuTTY console for experiment D: five `SEND:`/`RECEIVE:` pairs, `udp_client_thread stop!` |

The four TCP references (8.5 – 8.8) are the "four TCP reference screenshots"
referred to in the assignment.

## What these images establish about the expected console output

Useful details the guide's prose does not spell out, all visible in 8.6 / 8.8:

```
Entry address is 80200000            <- boot loader line
Clock_mask: 8000, step=100000        <- Clock_initialize()
 - RT - Thread Operating System 4.0.3 build Mar  2 2022
Welcome to RT-Thread.                <- main()
GMAC0_IP is : 192.168.1.123          <- ls1x_initialize_lwip() (defect D1/D2 area)
detect phy address == 17
msh />GMAC0: SPEED=100M, DUPLEX=FULL, LINK=UP. AN=YES.
GMAC0 controller initialized.
```

The wording of the socket messages differs slightly between editions of the
template (`succeed to ...` in this project, `success to ...` in Figure 8.8,
`succed to ...` in Figure 8.10). **That is cosmetic** — this project's source
prints `succeed to create sock_fd!`, `succeed to bind ip!`,
`succeed to listen!`, `succeed to connect to server!`.

Figure 8.9 also settles the dispute about section 8.2.14: the *prose* says
"Protocol type: TCP Server", but the author's own screenshot uses **UDP** mode
with local port 9062 and remote `192.168.1.123:9062`. The prose is the typo, the
figure is right — experiment C must be run in UDP mode.

## Real evidence lives elsewhere

Genuine captures of *this* project's runs belong in `../results/screenshots/`,
named exactly as listed in `../results/screenshots/README.md`. Those files do not
exist yet; the hardware experiments have not been performed.