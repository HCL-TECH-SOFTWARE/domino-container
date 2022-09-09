############################################################################
# Copyright Nash!Com, Daniel Nashed 2022 - APACHE 2.0 see LICENSE
############################################################################

# Requires: rapidjson-devel

CC=g++
CFLAGS= -g -Wall -c -m64 -fPIC -fpermissive
LIBS=

PROGRAM=checkjson

all: $(PROGRAM)

$(PROGRAM): $(PROGRAM).o
	 $(CC) -o $(PROGRAM) $(PROGRAM).o $(LIBS)

$(PROGRAM).o: $(PROGRAM).cpp
	$(CC)  $(CFLAGS) $(PROGRAM).cpp -DLINUX -DUNIX

clean:
	rm -f $(PROGRAM) *.o

test: all
	./$(PROGRAM)

install: all
	cp ./$(PROGRAM) /usr/bin/
	chmod 555 /usr/bin/$(PROGRAM)
