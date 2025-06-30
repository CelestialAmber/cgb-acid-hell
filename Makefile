ROM := cgb-acid-hell.gbc
OBJS := main.o wram.o

### Build tools

ifeq (,$(shell which sha1sum))
SHA1 := shasum
else
SHA1 := sha1sum
endif

### Build targets

.SUFFIXES:
.SECONDEXPANSION:
.PRECIOUS:
.SECONDARY:
.PHONY: all tools compare clean tidy

all: $(ROM)

compare: $(ROM)
	@$(SHA1) -c rom.sha1

tidy:
	rm -f $(ROM) $(OBJS) $(ROM:.gbc=.sym) $(ROM:.gbc=.map)

clean: tidy
	find . \( -iname '*.1bpp' -o -iname '*.2bpp' \) -exec rm {} +

tools:
	$(MAKE) -C tools/



ifeq (,$(filter clean tools,$(MAKECMDGOALS)))
$(info $(shell $(MAKE) -C tools))
endif

%.o: dep = $(shell tools/scan_includes $(@D)/$*.asm)
%.o: %.asm $$(dep)
	rgbasm -o $@ $<

PAD := 0
FIX_OPT := -v -C -n 0 -l 0x00 -m ROM -r 00 -t "CGB-ACID-HELL"

$(ROM): $(OBJS)
	rgblink -p $(PAD) -n $(ROM:.gbc=.sym) -m $(ROM:.gbc=.map) -o $@ $^
	rgbfix -p $(PAD) $(FIX_OPT) $@

%.2bpp: %.png
	rgbgfx -c embedded -o $@ $<

%.1bpp: %.png
	rgbgfx -d 1 -o $@ $<