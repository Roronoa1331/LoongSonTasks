from pathlib import Path
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.shared import Inches, Pt, RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn


ROOT = Path(__file__).resolve().parents[2]
DIGITAL = ROOT / "DigitalCalculator"
TEMPLATE = ROOT / "Computer_System_Comprehensive_Design_Report_Template_EN.docx"
OUTPUT = ROOT / "Computer_System_Comprehensive_Design_Final_Report.docx"


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_text(cell, text, bold=False, size=10.5):
    cell.text = ""
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(0)
    run = p.add_run(str(text))
    run.bold = bold
    run.font.size = Pt(size)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def add_page_number(paragraph):
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = paragraph.add_run("Page ")
    run.font.size = Pt(9)
    field = OxmlElement("w:fldSimple")
    field.set(qn("w:instr"), "PAGE")
    paragraph._p.append(field)


def clear_document(document):
    body = document._element.body
    for child in list(body):
        if child.tag != qn("w:sectPr"):
            body.remove(child)


def configure_document(document):
    section = document.sections[0]
    section.top_margin = Inches(0.75)
    section.bottom_margin = Inches(0.7)
    section.left_margin = Inches(0.9)
    section.right_margin = Inches(0.8)
    for style_name, size, bold in (
        ("Normal", 12, False),
        ("Title", 20, True),
        ("Heading 1", 15, True),
        ("Heading 2", 14, True),
        ("Heading 3", 12, True),
    ):
        style = document.styles[style_name]
        style.font.name = "Times New Roman"
        style._element.rPr.rFonts.set(qn("w:eastAsia"), "SimSun")
        style.font.size = Pt(size)
        style.font.bold = bold
    normal = document.styles["Normal"]
    normal.paragraph_format.line_spacing = 1.15
    normal.paragraph_format.space_after = Pt(6)
    add_page_number(section.footer.paragraphs[0])


def add_title(document, text, subtitle=False):
    p = document.add_paragraph()
    p.style = "Title" if not subtitle else "Normal"
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(12 if not subtitle else 6)
    run = p.add_run(text)
    run.font.name = "Times New Roman"
    run.font.size = Pt(20 if not subtitle else 14)
    run.bold = not subtitle
    return p


def add_heading(document, text, level=1):
    p = document.add_paragraph(text, style=f"Heading {level}")
    p.paragraph_format.keep_with_next = True
    return p


def add_para(document, text, italic=False):
    p = document.add_paragraph(style="Normal")
    p.paragraph_format.first_line_indent = Inches(0.25)
    run = p.add_run(text)
    run.italic = italic
    return p


def add_bullet(document, text, level=0):
    p = document.add_paragraph(style="Normal")
    p.paragraph_format.left_indent = Inches(0.25 + 0.2 * level)
    p.paragraph_format.first_line_indent = Inches(-0.15)
    p.add_run("• " + text)
    return p


def add_code(document, text):
    p = document.add_paragraph()
    p.paragraph_format.left_indent = Inches(0.25)
    p.paragraph_format.right_indent = Inches(0.15)
    p.paragraph_format.space_before = Pt(3)
    p.paragraph_format.space_after = Pt(6)
    p.paragraph_format.line_spacing = 1.0
    run = p.add_run(text.strip("\n"))
    run.font.name = "Consolas"
    run._element.rPr.rFonts.set(qn("w:eastAsia"), "Consolas")
    run.font.size = Pt(9)
    return p


def add_caption(document, text):
    p = document.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(8)
    run = p.add_run(text)
    run.italic = True
    run.font.size = Pt(10.5)
    return p


def add_table(document, headers, rows, widths=None):
    table = document.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.style = "Table Grid"
    for i, header in enumerate(headers):
        set_cell_text(table.rows[0].cells[i], header, bold=True)
        set_cell_shading(table.rows[0].cells[i], "D9EAF7")
    for row in rows:
        cells = table.add_row().cells
        for i, value in enumerate(row):
            set_cell_text(cells[i], value)
    if widths:
        for row in table.rows:
            for i, width in enumerate(widths):
                row.cells[i].width = Inches(width)
    document.add_paragraph().paragraph_format.space_after = Pt(0)
    return table


def add_image(document, path, caption, width=5.8):
    if not path.exists():
        add_para(document, f"[Evidence file unavailable: {path}]", italic=True)
        return
    p = document.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(str(path), width=Inches(width))
    add_caption(document, caption)


def add_text_evidence(document, path, caption, max_chars=2500):
    if not path.exists():
        add_para(document, f"[Evidence file unavailable: {path}]", italic=True)
        return
    text = path.read_text(encoding="utf-8", errors="replace")
    if len(text) > max_chars:
        text = text[:max_chars] + "\n[excerpt truncated; original file retained]"
    add_code(document, text)
    add_caption(document, caption)


def make_report():
    doc = Document(str(TEMPLATE))
    clear_document(doc)
    configure_document(doc)

    add_title(doc, "Computer System Comprehensive Design Report")
    add_title(doc, "Loongson LS1B200 / MIPS32 Experiments and Digital Calculator", subtitle=True)
    add_para(doc, "Major: ______________________________")
    add_para(doc, "Name: _______________________________")
    add_para(doc, "Class: _______________________________")
    add_para(doc, "Student ID: __________________________")
    add_para(doc, "Date: 17 November 2026")
    doc.add_page_break()

    add_title(doc, "Table of Contents")
    add_para(doc, "This editable report uses numbered headings. In Microsoft Word, right-click this page and choose “Update Field” if an automatic table of contents is required.")
    for item in [
        "Preface",
        "1. Introduction",
        "2. Chapter 5 — Assembly Code Implementation",
        "3. Chapter 6 — Serial-Port Controlled Running LED",
        "4. Chapter 7 — Sleeping-Barber Problem with RT-Thread",
        "5. Chapter 8 — Network Transmission with RT-Thread and lwIP",
        "6. Chapter 9 — RT-Thread TCP Client Example",
        "7. Final Project — Digital Calculator",
        "8. Overall Verification and Evidence",
        "9. Conclusion and Reflection",
        "10. Future Work",
        "Appendix — Evidence status",
    ]:
        add_bullet(doc, item)
    doc.add_page_break()

    add_heading(doc, "Preface", 1)
    add_para(doc, "This report consolidates the completed work in the Computer System Comprehensive Design project in the order in which the experiments were developed: MIPS32 assembly, serial-port controlled GPIO, RT-Thread synchronization, RT-Thread/lwIP networking, the Chapter 9 TCP-client example, and finally the Digital Calculator. It follows the supplied English report template and separates software/build verification from physical-board observations.")
    add_para(doc, "The project used the Loongson 1B/LS1B200 target model, the LoongIDE MIPS toolchain, RT-Thread 4.0.2 where required, and Windows host-side scripts for repeatable testing. The evidence policy is conservative: a build is reported as a build, a simulator run as a simulator run, and a hardware result is reported only when a real board and the necessary cable/software produced the result.")
    add_para(doc, "The most important distinction is between the two board routes used for the final project. The RT-Thread route provides the BSP, UART5 console and FinSH/MSH shell. The bare-metal route reuses the Chapter 5 startup/linker support and retargets newlib I/O to UART5, so it starts the calculator directly without RT-Thread. Both routes were built; the physical UART5 calculator console was not fully verified because the available COM8 adapter was the PMON/debug UART and the separate routed UART5 console was not connected.")

    add_heading(doc, "1. Introduction", 1)
    add_heading(doc, "1.1 Course context and target platform", 2)
    add_para(doc, "The experiments were designed for the Loongson LS1B200/LS232 MIPS32 platform with 64 MB low memory, a 200 MHz CPU and a 100 MHz bus as reported by the board monitor. The target uses little-endian MIPS32 and soft floating point. The native development machine was Windows with PowerShell, MinGW GCC and GNU Make; cross-compilation used the installed LoongIDE MIPS SDE Lite toolchain.")
    add_heading(doc, "1.2 Completed work and verification policy", 2)
    add_table(doc, ["Work item", "Verified result", "Hardware status"], [
        ("Chapter 5 assembly", "MIPS32 ELF and raw binary produced; source implements overflow-safe odd-number summation.", "No physical execution claimed."),
        ("Chapter 6 running LED", "UART3/GPIO command implementation and target artefacts present.", "No physical LED observation claimed."),
        ("Chapter 7 sleeping barber", "RT-Thread image built; host simulator ran nine scenarios plus repeatability checks, all PASS.", "Board console run not verified."),
        ("Chapter 8 TCP/UDP", "All four mutually exclusive firmware variants built successfully with logs and snapshots.", "All network exchanges remain NOT TESTED."),
        ("Chapter 9 TCP client", "RT-Thread/lwIP TCP-client project is present and `Build/example_9_1.exe/.bin` exists; TCP client is the enabled configuration.", "No physical TCP exchange was verified."),
        ("Digital Calculator", "Native 20/20 and MIPS simulator tests passed; RT-Thread and bare-metal images built.", "Image transfer was demonstrated; UART5 calculator output was not conclusively observed."),
    ])

    add_heading(doc, "2. Chapter 5 — Assembly Code Implementation", 1)
    add_heading(doc, "2.1 Objective and design", 2)
    add_para(doc, "The Chapter 5 task calculates the sum of consecutive odd numbers, 1 + 3 + 5 + … + (2n − 1), using MIPS32 assembly. The identity gives n², but the implementation intentionally performs the additions and checks for unsigned overflow before each addition. It stores the sum, count and overflow flag at fixed memory addresses.")
    add_table(doc, ["Address", "Meaning", "Verified value"], [
        ("0x80030000", "Accumulated sum", "0xFFFE0001"),
        ("0x80030004", "Number of terms", "0x0000FFFF"),
        ("0x80030008", "Overflow flag", "0x00000001"),
    ])
    add_heading(doc, "2.2 Implementation excerpt", 2)
    add_code(doc, """cal_loop:
    subu    t5, t3, t1
    sltu    t6, t5, t0
    bnez    t6, save_result
    nop
    addu    t0, t0, t1
    addiu   t1, t1, 2
    addiu   t2, t2, 1
    b       cal_loop
    nop""")
    add_caption(doc, "Figure 2.1: Chapter 5 overflow-safe accumulation excerpt from bsp_start.S.")
    add_para(doc, "The project includes Chapter 5 startup code, cache support, exception-vector support and a linker script placing code at 0x80200000. The generated `Build/example_7_2.exe` and `.bin` are target MIPS artefacts. No Windows-native execution or physical-board result is claimed because this program directly accesses target memory.")

    add_heading(doc, "3. Chapter 6 — Serial-Port Controlled Running LED", 1)
    add_heading(doc, "3.1 Functionality", 2)
    add_para(doc, "The Chapter 6 application is an RT-Thread LS1B project controlled through UART3 at 115200 baud. It drives eight active-low GPIO LEDs. The command parser accepts ON 1–8, OFF, SPEED 100–1000, START and STOP; invalid commands return ERR. After reset the application turns all LEDs off, selects LED 1 and uses a 500 ms default interval.")
    add_table(doc, ["Command", "Function", "Expected reply"], [
        ("ON 1 … ON 8", "Turn one selected LED on and stop running mode", "OK"),
        ("OFF", "Turn all LEDs off", "OK"),
        ("SPEED 100 … 1000", "Set interval in milliseconds", "OK"),
        ("START / STOP", "Start or pause the running LED", "OK"),
        ("Other or overlong input", "Reject the command", "ERR"),
    ])
    add_heading(doc, "3.2 Implementation excerpt", 2)
    add_code(doc, """void uart_init() {
    ls1x_uart_init(devUART3, NULL);
    ls1x_uart_open(devUART3, NULL);
}

void uart_send(const char *text) {
    char ch;
    while ((ch = *text++) != '\\0') {
        ls1x_uart_write(devUART3, &ch, 1, NULL);
    }
}""")
    add_caption(doc, "Figure 3.1: Chapter 6 UART3 initialization and output path.")
    add_para(doc, "The source, LoongIDE project and MIPS build artefacts are present. The available documentation provides the target procedure, but no genuine physical LED/serial result was recorded in the evidence set; therefore this report does not mark the hardware interaction as complete.")

    add_heading(doc, "4. Chapter 7 — Sleeping-Barber Problem with RT-Thread", 1)
    add_heading(doc, "4.1 Requirements and synchronization model", 2)
    add_para(doc, "Chapter 7 implements the classical sleeping-barber problem with one barber, five customer threads and three waiting-room chairs. The solution uses the guide's customers semaphore, barber semaphore, mutex and freeseats variable. RT-Thread priorities 5–9 are assigned to customers and priority 10 to the barber, reproducing the intended arrival order.")
    add_table(doc, ["Object", "Type", "Initial value", "Purpose"], [
        ("freeseats", "unsigned char", "3", "Number of free waiting chairs"),
        ("customers", "counting semaphore", "0", "Customers waiting for service"),
        ("barber", "counting semaphore", "0", "Barber ready signal"),
        ("mutex", "RT-Thread mutex", "1", "Protects freeseats"),
    ])
    add_heading(doc, "4.2 Algorithm excerpt", 2)
    add_code(doc, """if (freeseats > 0) {
    freeseats--;
    rt_sem_release(customers);
    rt_mutex_release(mutex);
    rt_sem_take(barber, RT_WAITING_FOREVER);
} else {
    rt_mutex_release(mutex);
}""")
    add_caption(doc, "Figure 4.1: Customer-side PV protocol as implemented in main.c.")
    add_para(doc, "The important correctness property is that a customer releases the mutex before waiting on barber. This avoids deadlock. The counting semaphore preserves wake-ups, and one barber release is performed for each seated customer.")
    add_heading(doc, "4.3 Dynamic verification", 2)
    add_para(doc, "The unmodified design source was executed against a host RT-Thread API simulator. The simulator preserves priority scheduling, semaphore blocking, mutex ownership and delays. Nine scenarios plus ten repeated runs of the default scenario passed.")
    add_table(doc, ["Scenario", "Customers", "Chairs", "Seated", "Turned away", "Haircuts", "Result"], [
        ("S1 zero customers", "0", "3", "0", "0", "0", "PASS"),
        ("S2 one customer", "1", "3", "1", "0", "1", "PASS"),
        ("S3 one chair", "1", "1", "1", "0", "1", "PASS"),
        ("S4 three customers", "3", "3", "3", "0", "3", "PASS"),
        ("S5 guide default", "5", "3", "3", "2", "3", "PASS"),
        ("S6 enough chairs", "5", "5", "5", "0", "5", "PASS"),
        ("S7 long run", "20", "1", "2", "18", "2", "PASS"),
        ("S8 long run", "20", "10", "11", "9", "11", "PASS"),
        ("S9 twenty chairs", "20", "20", "20", "0", "20", "PASS"),
        ("S5 repeated ×10", "5", "3", "3", "2", "3", "PASS"),
    ])
    add_para(doc, "The physical board console run was not verified. The image was built, but the hardware session log records that the UART5 console cable was not connected; COM8 was the PMON/debug UART.")

    add_heading(doc, "5. Chapter 8 — Network Transmission with RT-Thread and lwIP", 1)
    add_heading(doc, "5.1 Design and configurations", 2)
    add_para(doc, "Chapter 8 builds four mutually exclusive RT-Thread/lwIP firmware variants on GMAC0: TCP server, TCP client, UDP server/echo endpoint and UDP client. The board address is 192.168.1.123/24 and the intended PC address is 192.168.1.111/24. The four ports are TCP 9060 and 9061, and UDP 9062 and 9063.")
    add_table(doc, ["Variant", "Board role", "PC role", "Port", "Build", "Hardware communication"], [
        ("A TCP server", "Listen and echo", "TCP client", "9060", "SUCCESS", "NOT TESTED"),
        ("B TCP client", "Connect and exchange 5 cycles", "TCP server", "9061", "SUCCESS", "NOT TESTED"),
        ("C UDP server", "Receive and echo datagrams", "UDP sender", "9062", "SUCCESS", "NOT TESTED"),
        ("D UDP client", "Send 5 datagrams", "UDP receiver", "9063", "SUCCESS", "NOT TESTED"),
    ])
    add_heading(doc, "5.2 Implementation excerpt", 2)
    add_code(doc, """static unsigned char gmac0_ip[4] = {192, 168, 1, 123};

int main(int argc, char **argv)
{
    rt_kprintf("\\r\\nWelcome to RT-Thread.\\r\\n\\r\\n");
    ls1x_initialize_lwip(gmac0_ip, NULL);
    tcp_server_init(); /* selected by TEST_TCP_SERVER */
    return 0;
}""")
    add_caption(doc, "Figure 5.1: Network initialization and selected demo entry point.")
    add_para(doc, "All four configurations compiled successfully and their logs, snapshots, maps and raw images were retained. The physical experiment did not complete: the UART5 cable was not connected, the PC address could not be configured without elevation, and NetAssist was not installed. Consequently no TCP/UDP exchange, ping, ARP result or communication screenshot is claimed.")
    add_image(doc, ROOT / "Chapter08_ImplementationofNetworkTransmission/results/screenshots/board_console_boot_partial_2026-11-17.png", "Figure 5.2: Genuine partial board/console boot evidence from the Chapter 8 hardware attempt; it is not a network-success screenshot.", width=5.5)

    add_heading(doc, "6. Chapter 9 — RT-Thread TCP Client Example", 1)
    add_heading(doc, "6.1 Project purpose and configuration", 2)
    add_para(doc, "The Chapter 9 folder contains a separate RT-Thread 4.0.2 and lwIP 1.4.1 project named `example_9_1`. It demonstrates a board-side TCP client on the LS1B200 GMAC0 interface. The project configuration defines `TEST_TCP_CLIENT` as 1 and leaves the TCP server, UDP server and UDP client configurations disabled.")
    add_table(doc, ["Parameter", "Configured value"], [
        ("Board IP", "192.168.1.123"),
        ("Remote PC IP", "192.168.1.111"),
        ("Board TCP port", "9060"),
        ("Remote TCP port", "9061"),
        ("Protocol", "TCP stream socket"),
        ("Exchange count", "Five send/receive cycles"),
        ("RT-Thread", "4.0.2"),
        ("Target", "LS1B200, MIPS32 little-endian, soft-float"),
    ])
    add_heading(doc, "6.2 TCP-client workflow", 2)
    add_para(doc, "At startup the application prints the RT-Thread welcome message, initializes lwIP with the board address and creates the TCP-client thread. The thread creates a stream socket, connects to the configured PC address and port, sends a message containing the current tick count, waits for the response, and repeats this cycle five times before closing the socket.")
    add_code(doc, """#define TEST_TCP_CLIENT         1
#define TEST_TCP_SERVER         0
#define TEST_UDP_SERVER         0
#define TEST_UDP_CLIENT         0
#define TCP_LOCAL_PORT          9060
#define TCP_REMOTE_PORT         9061""")
    add_caption(doc, "Figure 6.1: Chapter 9 protocol-selection and port configuration from lwip_test.h.")
    add_code(doc, """snprintf(data_buf, 99, "client ticks = %i.\\n", ticks);
if (send(sock_fd, data_buf, strlen(data_buf), 0) <= 0) {
    delay_ms(1000);
    continue;
}
printk("SEND: %s", data_buf);
rdbytes = recv(sock_fd, data_buf, TCP_CLIENT_BUFSIZE, 0);
if (rdbytes > 0)
    printk("  RECEIVE: %s \\n", data_buf);""")
    add_caption(doc, "Figure 6.2: Chapter 9 TCP client send/receive loop.")
    add_heading(doc, "6.3 Build and execution status", 2)
    add_para(doc, "The folder contains the LoongIDE project file `example_9_1.lxp`, the linked executable `example_9_1.exe` and raw image `Build/example_9_1.bin`. The project file records the intended SDE Lite 4.9.2 compiler set and RT-Thread 4.0.2 configuration. The executable and raw image prove that the project was built, but the available evidence does not contain a completed TCP exchange with a configured PC peer. Therefore this report records the Chapter 9 hardware communication as NOT TESTED rather than claiming the five exchanges occurred.")
    add_para(doc, "Chapter 9 overlaps conceptually with Chapter 8, but it is retained as a distinct source project because it is a separate guide example with one enabled TCP-client configuration, its own project file and its own build artefacts. Chapter 8 remains the broader four-configuration implementation and comparison.")

    add_heading(doc, "7. Final Project — Digital Calculator", 1)
    add_heading(doc, "7.1 Purpose and objectives", 2)
    add_para(doc, "The Digital Calculator is the final menu-based C project. It performs addition, subtraction, multiplication and division, accepts integer and decimal numbers, rejects invalid input, prevents division by zero, repeats calculations without restarting and exits cleanly with option 5.")
    add_heading(doc, "7.2 Two board development routes", 2)
    add_table(doc, ["Route", "Implementation", "Console", "Status"], [
        ("Board + RT-Thread", "Shared calculator logic compiled with CALCULATOR_RTTHREAD; RT-Thread/FinSH adapter registers `calculator` as an MSH command.", "UART5, 115200 8-N-1; menu starts after `msh>` and option 5 returns to shell.", "Image built; physical calculator console not conclusively verified."),
        ("Board + bare-metal", "Chapter 5 startup/linker support, direct NS16550 UART5 driver, newlib `_read`/`_write` retargeting; no RT-Thread or FinSH.", "UART5, 115200 8-N-1; calculator should start directly.", "ELF/bin built and XMODEM transfer verified; output execution not conclusively verified."),
    ])
    add_para(doc, "The bare-metal route was initially prepared for UART3, then changed to UART5 after reviewing the working LS1B BSP and the board wiring evidence. The final bare-metal driver uses the LS1B UART5 base address 0xBFE7C000 and the BSP-compatible modem-control setting. The existing COM8 adapter is the PMON/debug UART; a separate routed UART5 connection is still required for reliable console observation.")
    add_heading(doc, "7.3 Core implementation", 2)
    add_code(doc, """int divide(double a, double b, double *result)
{
    if (b == 0.0) {
        return 0;
    }
    *result = a / b;
    return 1;
}""")
    add_caption(doc, "Figure 7.1: Division-by-zero protection from the final calculator source.")
    add_code(doc, """parsed = strtod(line, &end);
if (errno == ERANGE || *end != '\\0') {
    return -1;
}
*value = parsed;
return 1;""")
    add_caption(doc, "Figure 7.2: Whole-line numeric validation; trailing text is rejected.")
    add_code(doc, """#define UART5_BASE 0xBFE7C000u
...
void uart5_putc(char ch)
{
    while ((*uart5_reg(UART_LSR) & LSR_THR_EMPTY) == 0) {
    }
    *uart5_reg(UART_THR) = (unsigned char)ch;
}""")
    add_caption(doc, "Figure 7.3: Direct bare-metal UART5 output path.")
    add_heading(doc, "7.4 Automated test results", 2)
    add_para(doc, "The native PowerShell test runner executed all 20 repeatable cases. The native suite finished with 20 passed and 0 failed. The same test cases were also run against the MIPS instruction-set simulator, with 20/20 passing according to the retained project results.")
    calc_rows = [
        ("T01", "Addition", "1, 10, 5, 5", "Result: 15", "PASS"),
        ("T02", "Subtraction", "2, 10, 5, 5", "Result: 5", "PASS"),
        ("T03", "Multiplication", "3, 10, 5, 5", "Result: 50", "PASS"),
        ("T04", "Division", "4, 10, 5, 5", "Result: 2", "PASS"),
        ("T05", "Decimal addition", "1, 2.5, 1.5, 5", "Result: 4", "PASS"),
        ("T06", "Negative numbers", "1, -10, 5, 5", "Result: -5", "PASS"),
        ("T07", "Division by zero", "4, 10, 0, 5", "Division-by-zero error", "PASS"),
        ("T08", "Invalid menu 9", "9, 5", "Invalid selection message", "PASS"),
        ("T09", "Invalid number", "1, abc, 5", "Invalid numeric input", "PASS"),
        ("T10", "Exit", "5", "Goodbye.", "PASS"),
        ("T11", "Decimal division", "4, 1, 4, 5", "Result: 0.25", "PASS"),
        ("T12", "Negative multiplication", "3, -3.5, 2, 5", "Result: -7", "PASS"),
        ("T13", "Four calculations", "1/2/3/4 sequence", "15, 5, 50, 2", "PASS"),
        ("T14", "Menu option 0", "0, 5", "Invalid selection message", "PASS"),
        ("T15", "Trailing garbage", "1, 12abc, 5", "Invalid numeric input", "PASS"),
        ("T16", "Repeating decimal", "4, 10, 3, 5", "Result: 3.333333333", "PASS"),
        ("T17", "Empty menu input", "blank, 5", "Invalid selection message", "PASS"),
        ("T18", "End of input", "1, 10, 5, EOF", "Result: 15; EOF message", "PASS"),
        ("T19", "Negative zero", "3, 0, -3, 5", "Result: 0", "PASS"),
        ("T20", "Overlong number", "overlong numeric line", "Invalid numeric input", "PASS"),
    ]
    add_table(doc, ["ID", "Description", "Input summary", "Observed output", "Result"], calc_rows)
    add_heading(doc, "7.5 Console evidence", 2)
    add_para(doc, "The project contains genuine console-buffer captures rather than fabricated PNG screenshots. The capture script ran the real Windows calculator executable, injected real console keyboard events and read back the rendered console buffer. The files are retained as `.txt` evidence because no interactive desktop screenshot was available.")
    add_text_evidence(doc, DIGITAL / "screenshots/01_main_menu.txt", "Figure 7.4: Genuine captured Digital Calculator main menu.")
    add_text_evidence(doc, DIGITAL / "screenshots/02_addition.txt", "Figure 7.5: Genuine captured addition case: 10 + 5 = 15.")
    add_text_evidence(doc, DIGITAL / "screenshots/03_subtraction.txt", "Figure 7.6: Genuine captured subtraction case: 10 − 5 = 5.")
    add_text_evidence(doc, DIGITAL / "screenshots/06_division_by_zero.txt", "Figure 7.7: Genuine captured division-by-zero handling.")
    add_text_evidence(doc, DIGITAL / "screenshots/07_invalid_menu_option.txt", "Figure 7.8: Genuine captured invalid menu selection handling.")
    add_text_evidence(doc, DIGITAL / "screenshots/08_invalid_numeric_input.txt", "Figure 7.9: Genuine captured invalid numeric input handling.")
    add_text_evidence(doc, DIGITAL / "screenshots/10_exit.txt", "Figure 7.10: Genuine captured exit case.")
    add_heading(doc, "7.6 Board execution status", 2)
    add_para(doc, "The RT-Thread image `board_rtthread/Build/RThread6.bin` was built. The bare-metal image `board_baremetal/Build/calculator_baremetal.bin` was built as an ELF32 MIPS target with entry 0x80200000. PMON/XMODEM transfer of the bare-metal image to COM8 completed and reported `starting program at 0x80200000`. However, the available COM8 device was the PMON/debug UART, while the firmware console is UART5; no separate UART5 console cable was available. Later PMON output returned to `PMON>` and did not provide conclusive calculator output. The report therefore does not claim successful physical calculator interaction.")

    add_heading(doc, "8. Overall Verification and Evidence", 1)
    add_table(doc, ["Evidence category", "Result", "Interpretation"], [
        ("Source implementation", "Complete for Chapters 5–9 and Digital Calculator", "All requested experiment source areas and final project files exist."),
        ("Native calculator tests", "20/20 PASS", "Functional calculator behaviour verified on Windows."),
        ("MIPS simulator calculator tests", "20/20 PASS", "Portable calculator logic executed as MIPS32 in the SDE simulator."),
        ("RT-Thread sleeping barber", "All host scenarios PASS", "Synchronization algorithm dynamically checked without physical board."),
        ("Chapter 8 builds", "A/B/C/D SUCCESS", "All four network images compile and are logged."),
        ("Chapter 9 build", "example_9_1.exe/.bin present", "TCP-client project artefacts are present; exchange not tested."),
        ("Physical board transfer", "PMON/XMODEM transfer SUCCESS", "Board accepts images; this is not the same as application I/O verification."),
        ("Physical network experiments", "NOT TESTED", "UART5 cable, PC IP configuration and NetAssist were unavailable."),
        ("Physical calculator console", "NOT CONCLUSIVELY VERIFIED", "COM8 was not the routed UART5 console."),
    ])
    add_image(doc, ROOT / "Chapter08_ImplementationofNetworkTransmission/results/screenshots/Screenshot 2026-11-17 132541.png", "Figure 8.1: Genuine project screenshot retained from the Chapter 8 hardware/download session.", width=5.4)
    add_image(doc, ROOT / "Chapter08_ImplementationofNetworkTransmission/results/screenshots/Screenshot 2026-11-17 135939.png", "Figure 8.2: Genuine project screenshot retained from the Chapter 8 session; it is not presented as a completed network exchange.", width=5.4)

    add_heading(doc, "9. Conclusion and Reflection", 1)
    add_para(doc, "The course work progressed from direct MIPS32 arithmetic, through serial/GPIO control and RT-Thread synchronization, to a multi-configuration network application and a portable final calculator. The most useful engineering result is the separation of concerns: target startup and drivers are isolated from the calculator's arithmetic and validation logic, allowing the same calculator behaviour to be tested natively, in the MIPS simulator, under RT-Thread and in a bare-metal image.")
    add_para(doc, "The software evidence is strong: the calculator has 20/20 native and simulator tests, the sleeping-barber algorithm passes dynamic scenarios, and all four network variants build. The physical evidence is deliberately narrower: the board is alive, PMON accepts images, and LoongIDE/PMON build/download paths were investigated, but a UART5 cable and complete Ethernet test setup were not available. This distinction is important for a technically credible final submission.")

    add_heading(doc, "10. Future Work", 1)
    add_bullet(doc, "Connect the board's UART5 9-pin console to a second USB-serial adapter and capture the RT-Thread and bare-metal calculator menus.")
    add_bullet(doc, "Run the four Chapter 8 network images with the PC configured to 192.168.1.111/24 and NetAssist or the retained PowerShell peer tools.")
    add_bullet(doc, "Add a LoongIDE project file for the final bare-metal calculator and investigate direct EJTAG execution separately from PMON/XMODEM loading.")
    add_bullet(doc, "Extend the calculator with memory functions, scientific operations, a graphical interface or keypad input.")
    add_bullet(doc, "Add formal target-side smoke tests for UART input/output and reset/return behaviour.")

    add_heading(doc, "Appendix — Evidence status", 1)
    add_para(doc, "The following status labels are used throughout this report:")
    add_bullet(doc, "PASS / SUCCESS: directly supported by a retained build log, test output or simulator result.")
    add_bullet(doc, "TRANSFER SUCCESS: an image was loaded by PMON/XMODEM; this does not assert that the application produced console or network output.")
    add_bullet(doc, "NOT TESTED: the required physical setup was unavailable or the expected exchange was not observed.")
    add_bullet(doc, "NOT CONCLUSIVELY VERIFIED: an execution attempt occurred, but the available serial path did not prove the application's output.")
    add_para(doc, "Primary source documentation remains in the project folders: the individual chapter source files and project artefacts, Chapter 8 logs and CSV, Chapter 9 `example_9_1.lxp`, Digital Calculator `docs/FINAL_REPORT.md`, test result files, and screenshot evidence. The generator for this editable report is `DigitalCalculator/tools/create_final_report.py`.")

    doc.save(str(OUTPUT))
    print(OUTPUT)


if __name__ == "__main__":
    make_report()
