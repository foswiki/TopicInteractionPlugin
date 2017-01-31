FOSWIKI_ROOT?=~/foswiki/trunk/core
TARGET= \
  metadata.js \
  metadata.css \
  uploader.js \
  uploader.css

UPLOADER_SOURCE= \
  jquery.fileupload.uncompressed.js \
  foswiki.fileupload.uncompressed.js  

METADATA_SOURCE= \
  detectos.uncompressed.js \
  webdav.uncompressed.js \
  dialog.uncompressed.js \
  foswiki.attachments.uncompressed.js

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

.PRECIOUS: %.uncompressed.js

uploader.uncompressed.js: $(UPLOADER_SOURCE)
	@echo creating $@ from $^; echo "/* WARNING: THIS IS A DERIVED FILE. DON'T MODIFIY. */" > $@; $(CAT) $^ >> $@

metadata.uncompressed.js: $(METADATA_SOURCE)
	@echo creating $@ from $^; echo "/* WARNING: THIS IS A DERIVED FILE. DON'T MODIFIY. */" > $@; $(CAT) $^ >> $@

clean:
	rm -f $(TARGET) *.gz igp_* genpdf_*

ifneq (,$(wildcard dist))
%.uncompressed.js: dist/js/%.js
	cp $< $@
endif

