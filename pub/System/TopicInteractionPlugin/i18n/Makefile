FOSWIKI_ROOT?=~/foswiki/trunk/core
TARGET=\
  cs.js\
  da.js\
  de.js\
  es.js\
  fi.js\
  fr.js\
  it.js\
  ja.js\
  lv.js\
  nl.js\
  pt-br.js\
  ru.js\
  sv.js

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

from-git:
	cp ../git/src/javascript/i18n/*js .

to-git:
	cp *js ../git/src/javascript/i18n/
