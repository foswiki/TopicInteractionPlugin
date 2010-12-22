FOSWIKI_ROOT?=~/foswiki/trunk/core
TARGET= \
  metadata.js \
  metadata.css \
  metadata.pattern.css \
  gears.init.js \
  browserplus.init.js \
  plupload.browserplus.js \
  plupload.flash.js \
  plupload.gears.js \
  plupload.html4.js \
  plupload.html5.js \
  plupload.silverlight.js \
  plupload.js \
  jquery.uploader.js \
  jquery.uploader.css

SUBDIRS=i18n

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

to-git: 
	cp plupload.browserplus.uncompressed.js git/src/javascript/plupload.browserplus.js
	cp plupload.flash.swf git/bin/plupload.flash.swf
	cp plupload.flash.uncompressed.js git/src/javascript/plupload.flash.js
	cp plupload.gears.uncompressed.js git/src/javascript/plupload.gears.js
	cp plupload.html4.uncompressed.js git/src/javascript/plupload.html4.js
	cp plupload.html5.uncompressed.js git/src/javascript/plupload.html5.js
	cp plupload.silverlight.uncompressed.js git/src/javascript/plupload.silverlight.js
	cp plupload.uncompressed.js git/src/javascript/plupload.js

from-git:
	cp git/src/javascript/plupload.browserplus.js plupload.browserplus.uncompressed.js 
	cp git/bin/plupload.flash.swf plupload.flash.swf 
	cp git/src/javascript/plupload.flash.js plupload.flash.uncompressed.js 
	cp git/src/javascript/plupload.gears.js plupload.gears.uncompressed.js 
	cp git/src/javascript/plupload.html4.js plupload.html4.uncompressed.js 
	cp git/src/javascript/plupload.html5.js plupload.html5.uncompressed.js 
	cp git/src/javascript/plupload.silverlight.js plupload.silverlight.uncompressed.js 
	cp git/src/javascript/plupload.js plupload.uncompressed.js 

