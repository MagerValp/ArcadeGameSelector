#ECFLAGS=QUIET ERRLINE DEBUG LINEDEBUG
ECFLAGS=QUIET ERRLINE
EC=ec


%.m : %.e
	@Delete $@ QUIET >NIL:
	$(EC) $< $(ECFLAGS)

% : %.e
	@Delete $@ QUIET >NIL:
	$(EC) $< $(ECFLAGS)


all: AGS2 AGS2Helper


AGS2: AGS2.e agsil.m agsnav.m agsconf.m ilbmloader.m

AGS2Helper: AGS2Helper.e agsil.m ilbmloader.m benchmark.m


.PHONY: clean
clean:
	Delete AGS2 QUIET >NIL:
	Delete AGS2Helper QUIET >NIL:
	Delete agsil.m QUIET >NIL:
	Delete agsnav.m QUIET >NIL:
	Delete agsconf.m QUIET >NIL:
	Delete ilbmloader.m QUIET >NIL:
	Delete benchmark.m QUIET >NIL:
