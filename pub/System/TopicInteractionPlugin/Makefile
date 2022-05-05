FOSWIKI_ROOT?=~/foswiki/trunk/core
TARGET= \
  metadata.js \
  metadata.css \
  uploader.js \
  uploader.css \
  webdav.js

UPLOADER_SOURCE= \
  dialog.uncompressed.js \
  jquery.fileupload.uncompressed.js \
  foswiki.fileupload.uncompressed.js \
  legacy.fileupload.uncompressed.js 

METADATA_SOURCE= \
  detectos.uncompressed.js \
  webdav.uncompressed.js \
  foswiki.attachments.uncompressed.js

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

.PRECIOUS: %.uncompressed.js

uploader.uncompressed.js: $(UPLOADER_SOURCE)
	@echo creating $@; echo "/* WARNING: THIS IS A DERIVED FILE. DON'T MODIFIY. */" > $@; $(CAT) $^ >> $@

metadata.uncompressed.js: $(METADATA_SOURCE)
	@echo creating $@; echo "/* WARNING: THIS IS A DERIVED FILE. DON'T MODIFIY. */" > $@; $(CAT) $^ >> $@

clean:
	rm -f $(TARGET) *.gz igp_* genpdf_* *.jslint metadata.uncompressed.js uploader.uncompressed.js

.PHONY: git

git:
	git clone https://github.com/blueimp/jQuery-File-Upload.git git

ifneq (,$(wildcard git))
%.uncompressed.js: git/js/%.js
	@echo "generating $@"
	@$(CAT) $< > $@
endif
