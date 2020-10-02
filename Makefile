ALL = presentation.pdf speaker-notes.pdf article.html

TALK = talk.md

BEAMER_OPTS = --standalone \
  --pdf-engine=xelatex \
  --pdf-engine-opt=-shell-escape \
  --pdf-engine-opt=-output-directory=/tmp/pandoc \
  --slide-level=2 \
  --to beamer \
  --no-highlight \
  --lua-filter minted.lua


all: $(ALL)

presentation.pdf: $(TALK)
	pandoc $(BEAMER_OPTS) -o $@ $<

speaker-notes.pdf: $(TALK)
	pandoc $(BEAMER_OPTS) --metadata='classoption:notes=only' -o $@ $<

talk.pdf: $(TALK)
	pandoc --standalone --pdf-engine=xelatex --lua-filter minted.lua --pdf-engine-opt=-shell-escape --pdf-engine-opt=-output-directory=/tmp/pandoc --to pdf -o $@ $<

article.html: $(TALK)
	pandoc --standalone --to html	-o $@ $<


autoreload: ; while sleep 1; do $(MAKE); done

clean:
	git clean -dXf

install: $(ALL)
	mkdir -p $(out)
	cp $^ $(out)

.PHONY: all install clean autoreload
