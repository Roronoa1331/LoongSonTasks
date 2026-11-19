#include <errno.h>
#include <reent.h>
#include <stddef.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "uart5.h"

extern char _end;
extern char _heap_limit;
extern char _stack_start;

static char *heap_end;
static int baremetal_errno;

int *__errno(void)
{
    return &baremetal_errno;
}

int _write(int fd, const void *buffer, size_t count)
{
    const char *text = (const char *)buffer;
    size_t i;

    if (fd != 1 && fd != 2) {
        return -1;
    }

    for (i = 0; i < count; i++) {
        if (text[i] == '\n') {
            uart5_putc('\r');
        }
        uart5_putc(text[i]);
    }

    return (int)count;
}

int _read(int fd, void *buffer, size_t count)
{
    char *text = (char *)buffer;
    size_t i;

    if (fd != 0) {
        return -1;
    }

    for (i = 0; i < count; i++) {
        text[i] = (char)uart5_getc();
    }

    return (int)count;
}

int _close(int fd)
{
    (void)fd;
    return -1;
}

int _fstat(int fd, struct stat *st)
{
    if (fd < 0 || fd > 2) {
        return -1;
    }

    st->st_mode = S_IFCHR;
    return 0;
}

int _isatty(int fd)
{
    return (fd >= 0 && fd <= 2) ? 1 : 0;
}

off_t _lseek(int fd, off_t offset, int whence)
{
    (void)fd;
    (void)offset;
    (void)whence;
    return (off_t)-1;
}

int _getpid(void)
{
    return 1;
}

int _kill(int pid, int signal_number)
{
    (void)pid;
    (void)signal_number;
    errno = EINVAL;
    return -1;
}

void *_sbrk(ptrdiff_t increment)
{
    char *previous;
    /*
     * The stack sits in .bss and grows down from _stack_end; the heap starts
     * at _end (just above the stack) and grows up towards the end of RAM.
     * Limiting it to _stack_start is wrong: _end is already above that, so
     * every allocation (including newlib's printf float buffer) would fail.
     */
    char *limit = &_heap_limit;

    if (heap_end == 0) {
        heap_end = &_end;
    }

    previous = heap_end;
    if (increment < 0 || heap_end + increment > limit) {
        errno = ENOMEM;
        return (void *)-1;
    }

    heap_end += increment;
    return previous;
}

int _close_r(struct _reent *reent, int fd)
{
    (void)reent;
    return _close(fd);
}

int _fstat_r(struct _reent *reent, int fd, struct stat *st)
{
    (void)reent;
    return _fstat(fd, st);
}

int _isatty_r(struct _reent *reent, int fd)
{
    (void)reent;
    return _isatty(fd);
}

off_t _lseek_r(struct _reent *reent, int fd, off_t offset, int whence)
{
    (void)reent;
    return _lseek(fd, offset, whence);
}

ssize_t _read_r(struct _reent *reent, int fd, void *buffer, size_t count)
{
    (void)reent;
    return _read(fd, buffer, count);
}

ssize_t _write_r(struct _reent *reent, int fd, const void *buffer, size_t count)
{
    (void)reent;
    return _write(fd, buffer, count);
}

void *_sbrk_r(struct _reent *reent, ptrdiff_t increment)
{
    (void)reent;
    return _sbrk(increment);
}

void _exit(int status)
{
    (void)status;
    for (;;) {
    }
}
