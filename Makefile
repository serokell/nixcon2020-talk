TARGETS ?= presentation.pdf speaker-notes.pdf article.html

TALK = talk.md

RELOAD ?= presentation.pdf

BEAMER_OPTS = --standalone \
  --pdf-engine=xelatex \
  --pdf-engine-opt=-shell-escape \
  --pdf-engine-opt=-output-directory=_output \
  --slide-level=2 \
	--indented-code-classes=console \
  --to beamer \
  --no-highlight \
  --lua-filter minted.lua


all: $(TARGETS)

presentation.pdf: $(TALK)
	pandoc $(BEAMER_OPTS) -o $@ $<
	rm _output -rf

speaker-notes.pdf: $(TALK)
	pandoc $(BEAMER_OPTS) --metadata='classoption:notes=only' -o $@ $<
	rm _output -rf

article.html: $(TALK)
	pandoc --standalone --to html	-o $@ $<

autoreload: ; while sleep 1; do $(MAKE) $(RELOAD); done

clean:
	git clean -dXf

install: $(TARGETS)
	mkdir -p $(out)
	cp $^ $(out)

.PHONY: all install clean autoreload
