CC      = gcc
CFLAGS  = -std=c11 -O3 -Wall -Wextra -pthread
LDFLAGS = -pthread

PROGNAME = sieve
SRC      = main.c queue.c
OBJ      = $(SRC:.c=.o)

# Default run arguments (override with: make runlocal ARGS="-n 1000")
ARGS    ?=

.PHONY: all clean run runlocal help

all: $(PROGNAME)

$(PROGNAME): $(OBJ)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Local run 
runlocal: $(PROGNAME)
	./$(PROGNAME) $(ARGS)

# Cluster run 
run: $(PROGNAME)
	prun -v -np 1 ./$(PROGNAME) $(ARGS)

clean:
	rm -f $(PROGNAME) $(OBJ)