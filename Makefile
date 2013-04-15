#ECFLAGS=QUIET ERRLINE DEBUG LINEDEBUG
ECFLAGS=QUIET ERRLINE
EC=ec


%.m : %.e
	@Delete $@ QUIET >NIL:
	$(EC) $< $(ECFLAGS)

% : %.e
	@Delete $@ QUIET >NIL:
	$(EC) $< $(ECFLAGS)


all: ags2 irqimgloader


ags2: ags2.e agsil.m agsnav.m agsconf.m ilbmloader.m

irqimgloader: irqimgloader.e agsil.m ilbmloader.m benchmark.m


agsimgloader: agsimgloader.e agsil.m ilbmloader.m benchmark.m

testimgloader: testimgloader.e agsil.m

testnav: testnav.e agsnav.m

testconf: testconf.e agsconf.m


.PHONY: clean
clean:
	Delete ags2 QUIET >NIL:
	Delete agsimgloader QUIET >NIL:
	Delete testimgloader QUIET >NIL:
	Delete irqimgloader QUIET >NIL:
	Delete testnav QUIET >NIL:
	Delete testconf QUIET >NIL:
	Delete agsil.m QUIET >NIL:
	Delete agsnav.m QUIET >NIL:
	Delete agsconf.m QUIET >NIL:
	Delete ilbmloader.m QUIET >NIL:
	Delete benchmark.m QUIET >NIL:
