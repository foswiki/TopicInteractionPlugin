FOSWIKI_ROOT?=~/foswiki/trunk/core
TARGET= \
  build/metadata.js \
  build/metadata.css \
  build/uploader.js \
  build/uploader.css \
  build/webdav.js

UPLOADER_SOURCE= \
  src/dialog.uncompressed.js \
  src/jquery.fileupload.uncompressed.js \
  src/foswiki.fileupload.uncompressed.js \
  src/legacy.fileupload.uncompressed.js 

METADATA_SOURCE= \
  src/detectos.uncompressed.js \
  src/webdav.uncompressed.js \
  src/foswiki.attachments.uncompressed.js

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

.PRECIOUS: %.uncompressed.js

build/uploader.uncompressed.js: $(UPLOADER_SOURCE)
	@echo creating $@; echo "/* WARNING: THIS IS A DERIVED FILE. DON'T MODIFIY. */" > $@; $(CAT) $^ >> $@

build/metadata.uncompressed.js: $(METADATA_SOURCE)
	@echo creating $@; echo "/* WARNING: THIS IS A DERIVED FILE. DON'T MODIFIY. */" > $@; $(CAT) $^ >> $@

clean:
	rm -f build/* igp_* genpdf_* src/*.jslint 

.PHONY: git

git:
	git clone https://github.com/blueimp/jQuery-File-Upload.git git

ifneq (,$(wildcard git))
src/%.uncompressed.js: git/js/%.js
	@echo "generating $@"
	@$(CAT) $< > $@
endif
