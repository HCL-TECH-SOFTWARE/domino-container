
NODEBUG=1
PROGAM=checkjson

all: $(PROGAM).exe
# Link command

$(PROGAM).exe: $(PROGAM).obj
	link /SUBSYSTEM:CONSOLE /LARGEADDRESSAWARE $(PROGAM).obj -out:$@ -MAP 

# Compile command

$(PROGAM).obj: $(PROGAM).cpp
	cl -c /Zp /DWINVER=0x0602 $(PROGAM).cpp /Fo"$@" -In:/

clean:
	del *.obj *.pdb *.exe *.ilk *.sym *.map *.res

