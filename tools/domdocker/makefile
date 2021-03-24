#  makefile for domdocker Domino 9 64Bit Linux

# set TARGET to the name of the executable to create
TARGET = domdocker

# set SOURCES to the list of C source files in this program
SOURCES = $(TARGET).c

# set HEADERS to the list of C include files in this program
HEADERS =

# set OBJECTS to the list of object files that must be linked
OBJECTS = $(TARGET).o

# Link this program with the bootstrap code notes0.o because
# this program is structured as a NotesMain.
BOOTOBJS = $(LOTUS)/notesapi/lib/linux64/notes0.o $(LOTUS)/notesapi/lib/linux64/notesai0.o

# CC defines the compiler.
CC = g++

# Set CCOPTS - the compiler options.
CCOPTS = -c -m64
# You may use -g flag for debugging:
#CCOPTS = -c -mcpu=i486 -g

# set NOTESDIR to specify where to search for the Notes library file
NOTESDIR = $(Notes_ExecDirectory)

# Set LINKOPTS - the linker options passed to CC when linking.
# -o $(TARGET) causes compiler to create target rather than a.out
LINKOPTS = -o $(TARGET)

# Notes API header files require UNIX to be defined.
DEFINES = -DGCC3 -DGCC4 -fno-strict-aliasing -DGCC_LBLB_NOT_SUPPORTED -Wformat -Wall -Wcast-align -Wconversion  -DUNIX -DLINUX -DLINUX86 -DND64 -DLINUX64 -DW -DLINUX86_64 -DDTRACE -DPTHREAD_KERNEL -D_REENTRANT -DUSE_THREADSAFE_INTERFACES -D_POSIX_THREAD_SAFE_FUNCTIONS  -DHANDLE_IS_32BITS -DHAS_IOCP -DHAS_BOOL -DHAS_DLOPEN -DUSE_PTHREAD_INTERFACES -DLARGE64_FILES -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -DNDUNIX64 -DLONGIS64BIT   -DPRODUCTION_VERSION -DOVERRIDEDEBUG  -fPIC -Wno-write-strings

# set INCDIR to specify where to search for include files
INCDIR = $(LOTUS)/notesapi/include

# set LIBS to list all the libraries ld should link with.
LIBS = -lnotes -lm -lpthread -lc -ldl -lresolv

# the executable depends on the objects.
$(TARGET): $(OBJECTS)
	$(CC) $(LINKOPTS) $(OBJECTS) $(BOOTOBJS) -L$(NOTESDIR) -Wl,-rpath-link $(NOTESDIR) $(LIBS)

# the object files depend on the corresponding source files
.c.o:
	$(CC) $(CCOPTS) $(DEFINES) -I$(INCDIR) $(SOURCES)

