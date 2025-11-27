PROGNAME = assign3_1           # blocking (3.1)
PROGNAME_NB = assign3_1_nb     # non-blocking (3.2)

SRCFILES = assign3_1.c file.c timer.c simulate.c
TARNAME = assign3_1.tgz

RUNARGS = 1000 1000 # i_max t_max, increase this when testing on the DAS4!
NODES = 1 # How many DAS4 nodes
PROCESSESPERNODE = 1 # How many processes to spawn on one machine.

PRUNARGS = -v -np $(NODES) -$(PROCESSESPERNODE) \
		   -sge-script $$PRUN_ETC/prun-openmpi
IMAGEVIEW = display
CC = mpicc

WARNFLAGS = -Wall -Werror-implicit-function-declaration -Wshadow \
		  -Wstrict-prototypes -pedantic-errors
CFLAGS = -std=c99 -ggdb -O2 $(WARNFLAGS) -D_POSIX_C_SOURCE=200112
LFLAGS = -lm -lrt

# Do some substitution to get a list of .o files from the given .c files.
OBJFILES = $(patsubst %.c,%.o,$(SRCFILES))

.PHONY: all run run_nb runlocal runlocal_nb plot clean dist todo

# Default: build both, but main target is blocking
all: $(PROGNAME) $(PROGNAME_NB)

# Blocking version (3.1) – no extra defines
$(PROGNAME): $(OBJFILES)
	$(CC) $(CFLAGS) -o $@ $^ $(LFLAGS)

# Non-blocking version (3.2) – define USE_NONBLOCKING
$(PROGNAME_NB): $(OBJFILES)
	$(CC) $(CFLAGS) -DUSE_NONBLOCKING -o $@ $^ $(LFLAGS)

%.o: %.c
	$(CC) -c $(CFLAGS) -o $@ $<

# Run blocking version on DAS
run: $(PROGNAME)
	prun $(PRUNARGS) $(PROGNAME) $(RUNARGS)

# Run non-blocking version on DAS
run_nb: $(PROGNAME_NB)
	prun $(PRUNARGS) $(PROGNAME_NB) $(RUNARGS)

# Run blocking version locally
runlocal: $(PROGNAME)
	mpirun -n $(PROCESSESPERNODE) $(PROGNAME) $(RUNARGS)

# Run non-blocking version locally
runlocal_nb: $(PROGNAME_NB)
	mpirun -n $(PROCESSESPERNODE) $(PROGNAME_NB) $(RUNARGS)

plot: result.txt
	gnuplot plot.gnp
	$(IMAGEVIEW) plot.png

dist:
	tar cvzf $(TARNAME) Makefile *.c *.h data/

clean:
	rm -fv $(PROGNAME) $(PROGNAME_NB) $(OBJFILES) $(TARNAME) result.txt plot.png
