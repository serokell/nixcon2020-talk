ALL = presentation.pdf speaker-notes.pdf article.html

TALK = talk.md

THEME ?= Nord

LOGO ?= images/logo-small.png

BEAMER_OPTS = --standalone --pdf-engine=xelatex --slide-level=2 --to beamer


all: $(ALL)

.PHONY: all

presentation.pdf: $(TALK)
	pandoc $(BEAMER_OPTS) -o $@ $<

speaker-notes.pdf: $(TALK)
	pandoc $(BEAMER_OPTS) --metadata='classoption:notes=only' -o $@ $<

article.html: $(TALK)
	pandoc --standalone --to html	-o $@ $<


autoreload: ; while sleep 1; do $(MAKE); done

clean:
	git clean -dXf

install: $(ALL)
	mkdir -p $(out)
	cp $^ $(out)

.PHONY: all install clean autoreload
